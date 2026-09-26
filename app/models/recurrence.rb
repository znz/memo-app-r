# frozen_string_literal: true

# Repeat rules of reminders stored as JSON (see Recurrence.build)
module Recurrence
  # Raised when a rule hash is not valid
  class InvalidRule < StandardError
    I18N_SCOPE = "activerecord.errors.models.reminder.attributes.recurrence"

    attr_reader :error_key, :options

    def initialize(error_key, **options)
      @error_key = error_key
      @options = options
      super(I18n.t(:"activerecord.attributes.reminder.recurrence") + I18n.t(error_key, scope: I18N_SCOPE, **options))
    end
  end

  RULES = [None, Hourly, Daily, Weekly, Monthly, Yearly, AfterCompletion].index_by(&:type).freeze

  # Choices of the reminder form (labels: recurrence.presets.*)
  PRESETS = {
    "none" => { "type" => "none" },
    "hourly" => { "type" => "hourly" },
    "every_6_hours" => { "type" => "hourly", "interval" => 6 },
    "every_8_hours" => { "type" => "hourly", "interval" => 8 },
    "daily" => { "type" => "daily" },
    "weekdays" => { "type" => "weekly", "weekdays" => [1, 2, 3, 4, 5] },
    "weekly" => { "type" => "weekly" },
    "biweekly" => { "type" => "weekly", "interval" => 2 },
    "monthly" => { "type" => "monthly" },
    "monthly_last_wednesday" => { "type" => "monthly", "nth" => -1, "weekday" => 3 },
    "yearly" => { "type" => "yearly" },
    "after_1_hour" => { "type" => "after_completion", "cooldown_minutes" => 60 },
    "after_1_hour_5_per_day" => { "type" => "after_completion", "cooldown_minutes" => 60, "max_per_day" => 5 }
  }.transform_values(&:freeze).freeze

  # Builds a frozen rule object from a hash with string or symbol keys
  def self.build(hash)
    raise InvalidRule, :not_a_hash unless hash.is_a?(Hash)

    attributes = hash.to_h { |key, value| [key.to_s, value] }
    type = attributes.delete("type").to_s
    rule_class = RULES[type] or raise InvalidRule.new(:unknown_type, type:)
    rule_class.from_hash(attributes)
  end
end
