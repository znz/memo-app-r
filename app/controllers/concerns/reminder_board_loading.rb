# frozen_string_literal: true

# Reminders of the current user shown on the memo pages
module ReminderBoardLoading
  extend ActiveSupport::Concern

  included do
    helper_method :hidden_tag_ids
  end

  private

  # Ids of the tags hidden on this device (saved by HiddenTagsController)
  def hidden_tag_ids
    @hidden_tag_ids ||= cookies[:hidden_tag_ids].to_s.split(",")
  end

  def build_reminder_board(scope = current_user.reminders)
    ReminderBoard.new(scope.enabled.includes(:tags), hidden_tag_ids:)
  end

  def load_reminder_board
    @reminder_board = build_reminder_board
    @hideable_tags = current_user.tags.enabled.order(:name)
  end
end
