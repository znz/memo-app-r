# frozen_string_literal: true

# Memo data
class Memo < ApplicationRecord
  include Base58Uuid

  NEARBY_REMINDERS_WITHIN = 30.minutes

  belongs_to :user
  has_many :memo_tags, dependent: :destroy
  has_many :tags, -> { order(:name) }, through: :memo_tags

  validate :tags_must_be_owned

  # Nearby reminders are shown on a memo with location just after its creation
  def nearby_reminders_visible?(now = Time.current)
    lonlat.present? && created_at.present? && created_at >= now - NEARBY_REMINDERS_WITHIN
  end

  private def tags_must_be_owned
    errors.add(:tag_ids, :not_owned) if tags.any? { it.user_id != user_id }
  end

  # Memos with all the given tags (ids)
  scope :tags_contains, lambda { |*ids|
    ids.compact_blank.inject(all) { |memos, id| memos.where(id: MemoTag.where(tag_id: id).select(:memo_id)) }
  }

  def self.ransackable_attributes(_auth_object = nil)
    ["content", "create_from", "created_at", "created_on", "hostname", "id", "info", "lonlat", "price", "updated_at", "user_agent"]
  end

  # Memos are always searched within current_user.memos, so the user is not searchable
  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def self.ransackable_scopes(_auth_object = nil)
    %i[tags_contains]
  end

  include RansackerCreatedOn
end
