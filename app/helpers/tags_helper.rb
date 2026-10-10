# frozen_string_literal: true

module TagsHelper
  # Options of the select of memo_use (target: :memo) or reminder_use (target: :reminder)
  def tag_use_options(target)
    Tag::USES.map { [t("tags.uses.#{target}.#{it}"), it] }
  end

  # Badge of a tag on the reminder form, followed by "（無効）" when disabled for reminders
  def reminder_tag_label(tag_record)
    badge = theme_badge(tag_record.name, tag_record.color)
    return badge unless tag_record.reminder_disabled?

    safe_join([badge, tag.small(t("tags.disabled_label"), class: "text-muted")])
  end
end
