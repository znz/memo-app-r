# frozen_string_literal: true

# Reminder shown on the new memo page
class Reminder < ApplicationRecord
  include Base58Uuid

  URGENT_WITHIN = 1.hour
  URGENT_RATIO = 0.25
  UNDO_EXPIRES_IN = 1.hour

  belongs_to :user
  has_many :reminder_tags, dependent: :destroy
  has_many :tags, -> { order(:name) }, through: :reminder_tags

  attribute :recurrence_preset, :string
  attribute :recurrence_json, :string
  attribute :latitude, :float
  attribute :longitude, :float

  normalizes :memo_tags, with: ->(tags) { Array(tags).compact_blank.uniq }, apply_to_nil: true

  before_validation :assign_recurrence_input
  before_validation :assign_lonlat
  after_save :clear_coordinates_assigned

  validates :name, presence: true
  validates :radius_m, numericality: { only_integer: true, greater_than: 0 }
  validates :starts_at, presence: true, if: -> { valid_rule&.windowed? }
  validates :latitude, numericality: { in: -90..90 }, allow_nil: true
  validates :longitude, numericality: { in: -180..180 }, allow_nil: true
  validate :coordinates_must_be_paired
  validate :recurrence_must_be_valid
  validate :recurrence_input_must_be_valid
  validate :times_must_be_ordered
  validate :tags_must_be_owned

  scope :enabled, -> { where(enabled: true) }

  NEAR_POINT_SQL = "ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography"

  # Reminders whose radius contains the point, nearest first, with distance_m (read it by reminder[:distance_m]).
  # Do not call count on this relation: use to_a.size or count(:all).
  scope :near, ->(point) {
    return none if point.nil?

    binds = { lon: point.x, lat: point.y }
    where("ST_DWithin(reminders.lonlat, #{NEAR_POINT_SQL}, reminders.radius_m)", binds)
      .select("reminders.*", sanitize_sql_array(["ST_Distance(reminders.lonlat, #{NEAR_POINT_SQL}) AS distance_m", binds]))
      .order(Arel.sql("distance_m"))
  }

  def self.undo_verifier = Rails.application.message_verifier(:reminder_undo)

  # Rule object built from recurrence (rebuilt when recurrence changes)
  def rule
    if @rule.nil? || @rule_source != recurrence
      @rule = Recurrence.build(recurrence)
      @rule_source = recurrence.deep_dup
    end
    @rule
  end

  # Virtual attributes of the form: read from lonlat unless assigned, and written to lonlat before validation
  def latitude = @latitude_assigned ? super : lonlat&.y

  def longitude = @longitude_assigned ? super : lonlat&.x

  def latitude=(value)
    @latitude_assigned = true
    super
  end

  def longitude=(value)
    @longitude_assigned = true
    super
  end

  def reload(...)
    clear_coordinates_assigned
    super
  end

  def schedule
    Reminder::Schedule.new(rule:, starts_at:, due_at:, repeat_until:)
  end

  def status_at(now = Time.current)
    return Status.new(state: :disabled) unless enabled?

    if rule.windowed?
      windowed_status_at(now)
    elsif rule.is_a?(Recurrence::AfterCompletion)
      after_completion_status_at(now)
    else
      single_status_at(now)
    end
  end

  # Completions on the local date of time
  def completed_count_on(time)
    (last_completed_at&.to_date == time.in_time_zone.to_date) ? completed_count : 0
  end

  def complete!(now = Time.current)
    update!(completed_count: completed_count_on(now) + 1, last_completed_at: now)
  end

  # Attributes of the new memo made after the completion
  def memo_attributes
    { content: memo_template.presence || name, tags: memo_tags }
  end

  # Signed token to restore the state before the completion
  def undo_token
    payload = { "id" => id, "last_completed_at" => last_completed_at&.iso8601(6), "completed_count" => completed_count }
    self.class.undo_verifier.generate(payload, expires_in: UNDO_EXPIRES_IN, purpose: :undo_complete)
  end

  # Returns true when restored, false when the token is invalid, expired or for another reminder
  def undo_complete!(token)
    payload = token.present? && self.class.undo_verifier.verified(token, purpose: :undo_complete)
    return false unless payload.is_a?(Hash) && payload["id"] == id

    last_completed_at = payload["last_completed_at"] && Time.zone.iso8601(payload["last_completed_at"])
    update!(last_completed_at:, completed_count: payload["completed_count"])
  end

  # No windows: starts_at enables, repeat_until ends, and only the one hour rule makes it urgent.
  # Expired also when the limit of the day or the cooldown lasts until repeat_until.
  private def after_completion_status_at(now)
    repeat_limit = schedule.repeat_limit
    limit_reached = rule.max_per_day && completed_count_on(now) >= rule.max_per_day
    cooldown_ends_at = last_completed_at && (last_completed_at + rule.cooldown_minutes.minutes)
    available_at = [now, (now.tomorrow.beginning_of_day if limit_reached), cooldown_ends_at].compact.max
    if starts_at && now < starts_at
      Status.new(state: :waiting, starts_at:)
    elsif repeat_limit && available_at >= repeat_limit
      Status.new(state: :expired)
    elsif limit_reached
      Status.new(state: :limit_reached, starts_at: available_at)
    elsif now < available_at
      Status.new(state: :cooling_down, starts_at: available_at)
    else
      Status.new(state: :active, ends_at: [(now.end_of_day if rule.max_per_day), repeat_limit].compact.min)
    end
  end

  private def windowed_status_at(now)
    window = schedule.window_at(now)
    if window.nil?
      next_window = schedule.next_window_after(now)
      return Status.new(state: :expired) unless next_window

      Status.new(state: :waiting, starts_at: next_window.starts_at, ends_at: next_window.ends_at)
    elsif last_completed_at && window.cover?(last_completed_at)
      Status.new(state: :done, starts_at: window.starts_at, ends_at: window.ends_at)
    else
      Status.new(state: :active, starts_at: window.starts_at, ends_at: window.ends_at)
    end
  end

  private def single_status_at(now)
    start = starts_at || created_at
    ends_at = Schedule.exclusive_end(due_at) if due_at
    if last_completed_at
      Status.new(state: :done, starts_at: start, ends_at:)
    elsif start.nil? || now < start
      Status.new(state: :waiting, starts_at: start, ends_at:)
    elsif ends_at && now >= ends_at
      Status.new(state: :overdue, starts_at: start, ends_at:)
    else
      Status.new(state: :active, starts_at: start, ends_at:)
    end
  end

  private def clear_coordinates_assigned
    @latitude_assigned = @longitude_assigned = false
  end

  private def assign_lonlat
    return unless @latitude_assigned || @longitude_assigned

    if latitude.nil? && longitude.nil?
      self.lonlat = nil
    elsif latitude && longitude && (-90..90).cover?(latitude) && (-180..180).cover?(longitude)
      self.lonlat = "POINT(#{longitude} #{latitude})"
    end
  end

  private def coordinates_must_be_paired
    errors.add(:latitude, :pair) if latitude.nil? != longitude.nil?
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
