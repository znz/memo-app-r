# frozen_string_literal: true

# Reminder shown on the new memo page
class Reminder < ApplicationRecord
  include Base58Uuid

  belongs_to :user
  has_many :reminder_tags, dependent: :destroy
  has_many :tags, -> { order(:name) }, through: :reminder_tags

  attribute :recurrence_preset, :string
  attribute :recurrence_json, :string

  normalizes :memo_tags, with: ->(tags) { Array(tags).compact_blank.uniq }, apply_to_nil: true

  before_validation :assign_recurrence_input

  validates :name, presence: true
  validates :radius_m, numericality: { only_integer: true, greater_than: 0 }
  validates :starts_at, presence: true, if: -> { valid_rule&.windowed? }
  validate :recurrence_must_be_valid
  validate :recurrence_input_must_be_valid
  validate :times_must_be_ordered
  validate :tags_must_be_owned

  scope :enabled, -> { where(enabled: true) }

  # Rule object built from recurrence (rebuilt when recurrence changes)
  def rule
    if @rule.nil? || @rule_source != recurrence
      @rule = Recurrence.build(recurrence)
      @rule_source = recurrence.deep_dup
    end
    @rule
  end

  private def valid_rule
    rule
  rescue Recurrence::InvalidRule
    nil
  end

  private def assign_recurrence_input
    @recurrence_input_error = nil
    if recurrence_json.present?
      begin
        self.recurrence = JSON.parse(recurrence_json)
      rescue JSON::ParserError
        @recurrence_input_error = [:recurrence_json, :invalid_json]
      end
    elsif recurrence_preset.present?
      if Recurrence::PRESETS.key?(recurrence_preset)
        self.recurrence = Recurrence::PRESETS[recurrence_preset].deep_dup
      else
        @recurrence_input_error = [:recurrence_preset, :inclusion]
      end
    end
  end

  private def recurrence_input_must_be_valid
    errors.add(*@recurrence_input_error) if @recurrence_input_error
  end

  private def recurrence_must_be_valid
    rule
  rescue Recurrence::InvalidRule => e
    errors.add(:recurrence, e.error_key, **e.options)
  end

  private def times_must_be_ordered
    errors.add(:due_at, :not_allowed) if due_at && valid_rule.is_a?(Recurrence::AfterCompletion)
    return unless starts_at

    errors.add(:due_at, :after_starts_at) if due_at && due_at <= starts_at
    errors.add(:repeat_until, :after_starts_at) if repeat_until && repeat_until <= starts_at
  end

  private def tags_must_be_owned
    errors.add(:tag_ids, :not_owned) if tags.any? { it.user_id != user_id }
  end
end
