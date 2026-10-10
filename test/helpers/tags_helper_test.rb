# frozen_string_literal: true

require "test_helper"

class TagsHelperTest < ActionView::TestCase
  include RemindersHelper

  private def current_user = users(:one)

  test "memo_tag_candidates are the tags enabled for memos and the given tags, the disabled ones last" do
    assert_equal %i[tag1 tag2 work medicine].map { tags(it) }, memo_tag_candidates([], include_disabled: false)
    assert_equal %i[tag1 tag2 work medicine old].map { tags(it) }, memo_tag_candidates([tags(:old)], include_disabled: false)
    assert_equal %i[tag1 tag2 work medicine old].map { tags(it) }, memo_tag_candidates([], include_disabled: true)
  end

  test "memo_tag_label is a badge marked when disabled for memos" do
    assert_dom_equal '<span class="badge badge-secondary">tag1</span>', memo_tag_label(tags(:tag1))
    assert_dom_equal '<span class="badge badge-secondary">旧メモ</span><small class="text-muted">（無効）</small>', memo_tag_label(tags(:old))
  end
end
