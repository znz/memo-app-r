# frozen_string_literal: true

module TagsHelper
  # Options of the select of memo_use (target: :memo) or reminder_use (target: :reminder)
  def tag_use_options(target)
    Tag::USES.map { [t("tags.uses.#{target}.#{it}"), it] }
  end

  # Badge of a tag on the reminder form, followed by "（無効）" when disabled for reminders
  def reminder_tag_label(tag_record) = tag_label(tag_record, disabled: tag_record.reminder_disabled?)

  # Badge of a tag for memos, followed by "（無効）" when disabled for memos
  def memo_tag_label(tag_record) = tag_label(tag_record, disabled: tag_record.memo_disabled?)

  # Tags of the current user for memos (only the enabled ones without include_disabled) and the selected ones,
  # the disabled ones last
  def memo_tag_candidates(selected, include_disabled:)
    tags = include_disabled ? current_user.tags.not_memo_unused : current_user.tags.memo_enabled
    (tags.to_a | selected.to_a).sort_by { [it.memo_disabled? ? 1 : 0, it.name] }
  end

  private def tag_label(tag_record, disabled:)
    badge = theme_badge(tag_record.name, tag_record.color)
    return badge unless disabled

    safe_join([badge, tag.small(t("tags.disabled_label"), class: "text-muted")])
  end
end
