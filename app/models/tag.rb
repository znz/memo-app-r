# frozen_string_literal: true

# Tag owned by a user
class Tag < ApplicationRecord
  include Base58Uuid

  belongs_to :user
  has_many :reminder_tags, dependent: :destroy
  has_many :reminders, through: :reminder_tags

  USES = %w[unused enabled disabled].freeze

  enum :memo_use, USES.index_by(&:itself), prefix: :memo, validate: true
  enum :reminder_use, USES.index_by(&:itself), prefix: :reminder, validate: true

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :color, inclusion: { in: ThemeColor::COLORS }
  validate :used_somewhere
  validate :reminder_use_unused_without_reminders, if: -> { reminder_use_changed? && reminder_unused? }

  # For the list of the tags: reminders_count
  scope :with_counts, lambda {
    left_joins(:reminder_tags)
      .group(:id)
      .select("tags.*", "COUNT(reminder_tags.id) AS reminders_count")
  }

  private def used_somewhere
    errors.add(:base, :no_use) if memo_unused? && reminder_unused?
  end

  private def reminder_use_unused_without_reminders
    count = reminder_tags.count
    errors.add(:reminder_use, :in_use, count:) if count.positive?
  end
end
