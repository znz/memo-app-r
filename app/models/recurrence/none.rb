# frozen_string_literal: true

# Only once
class Recurrence::None < Recurrence::Rule
  def windowed? = false

  def occurrence_at_or_before(time, anchor:)
    anchor if anchor <= time
  end

  def occurrence_after(time, anchor:)
    anchor if anchor > time
  end

  def label = I18n.t("recurrence.labels.none")
end
