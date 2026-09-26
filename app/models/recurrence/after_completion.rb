# frozen_string_literal: true

# Available again `cooldown_minutes` after the last completion, at most `max_per_day` times a day.
# It has no windows: starts_at enables it and repeat_until ends it.
class Recurrence::AfterCompletion < Recurrence::Rule
  KEYS = %w[cooldown_minutes max_per_day].freeze

  attr_reader :cooldown_minutes, :max_per_day

  def initialize(attributes)
    super
    raise Recurrence::InvalidRule, :invalid_cooldown_minutes unless @values.key?("cooldown_minutes")

    @cooldown_minutes = positive_integer("cooldown_minutes", :invalid_cooldown_minutes)
    @max_per_day = positive_integer("max_per_day", :invalid_max_per_day)
  end

  def windowed? = false

  def occurrence_at_or_before(_time, anchor:) = nil

  def occurrence_after(_time, anchor:) = nil

  def label
    label = I18n.t("recurrence.labels.after_completion", minutes: cooldown_minutes)
    max_per_day ? label + I18n.t("recurrence.labels.max_per_day", count: max_per_day) : label
  end
end
