# frozen_string_literal: true

# Memo data
class Memo < ApplicationRecord
  include Base58Uuid

  NEARBY_REMINDERS_WITHIN = 30.minutes

  acts_as_taggable_array_on :tags
  belongs_to :user

  # Distinct tags of the memos of the user (all_tags ignores the current scope)
  def self.all_tags_for(user)
    user_id = user.id
    all_tags { where(user_id: user_id) }
  end

  # Nearby reminders are shown on a memo with location just after its creation
  def nearby_reminders_visible?(now = Time.current)
    lonlat.present? && created_at.present? && created_at >= now - NEARBY_REMINDERS_WITHIN
  end

  private def validate_tags
    if !tags.is_a?(Array) || tags.any?(&:blank?)
      errors.add(:tags, :invalid)
    end
  end

  private def unique_tags
    if tags.is_a?(Array)
      self.tags = tags.uniq.sort.compact_blank
    end
  end
  before_validation :unique_tags

  scope :tags_contains, ->(*values) {
    where("tags @> ARRAY[?]::varchar[]", values&.map(&:to_s))
  }

  def self.ransackable_attributes(_auth_object = nil)
    ["content", "create_from", "created_at", "created_on", "hostname", "id", "info", "lonlat", "price", "tags", "updated_at", "user_agent"]
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
