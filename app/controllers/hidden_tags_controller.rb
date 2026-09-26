# frozen_string_literal: true

# Tags whose reminders are hidden on this device (saved in a cookie)
class HiddenTagsController < ApplicationController
  def create
    ids = current_user.tags.where(id: params.expect(tag_ids: []).compact_blank).pluck(:id)
    if ids.empty?
      cookies.delete(:hidden_tag_ids)
    else
      cookies.permanent[:hidden_tag_ids] = { value: ids.join(","), httponly: true, same_site: :lax }
    end
    redirect_back_or_to new_memo_path, notice: t(".success")
  end
end
