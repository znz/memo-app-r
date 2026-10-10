# frozen_string_literal: true

# Join model of memos and the tags on them
class MemoTag < ApplicationRecord
  belongs_to :memo
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :memo_id }
end
