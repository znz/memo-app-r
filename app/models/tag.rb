# frozen_string_literal: true

# Tag owned by a user
class Tag < ApplicationRecord
  include Base58Uuid

  belongs_to :user
  has_many :reminder_tags, dependent: :destroy
  has_many :reminders, through: :reminder_tags
  has_many :memo_tags, dependent: :restrict_with_error
  has_many :reminder_memo_tags, dependent: :destroy

  USES = %w[unused enabled disabled].freeze

  attribute :last_memo_at, :datetime # selected by with_counts

  enum :memo_use, USES.index_by(&:itself), prefix: :memo, validate: true
  enum :reminder_use, USES.index_by(&:itself), prefix: :reminder, validate: true

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :color, inclusion: { in: ThemeColor::COLORS }
  validate :used_somewhere
  validate :memo_use_unused_without_memos, if: -> { memo_use_changed? && memo_unused? }
  validate :reminder_use_unused_without_reminders, if: -> { reminder_use_changed? && reminder_unused? }

  # For the list of the tags: reminders_count, memos_count and last_memo_at (the time of the last memo)
  scope :with_counts, lambda {
    select(
      "tags.*",
      "(SELECT COUNT(*) FROM reminder_tags WHERE reminder_tags.tag_id = tags.id) AS reminders_count",
      "(SELECT COUNT(*) FROM memo_tags WHERE memo_tags.tag_id = tags.id) AS memos_count",
      "(SELECT MAX(memos.created_at) FROM memo_tags JOIN memos ON memos.id = memo_tags.memo_id WHERE memo_tags.tag_id = tags.id) AS last_memo_at"
    )
  }

  private def used_somewhere
    errors.add(:base, :no_use) if memo_unused? && reminder_unused?
  end

  private def memo_use_unused_without_memos
    count = memo_tags.count + reminder_memo_tags.count
    errors.add(:memo_use, :in_use, count:) if count.positive?
  end

  private def reminder_use_unused_without_reminders
    count = reminder_tags.count
    errors.add(:reminder_use, :in_use, count:) if count.positive?
  end
end
