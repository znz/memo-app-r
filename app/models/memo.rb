# frozen_string_literal: true

# Memo data
class Memo < ApplicationRecord
  acts_as_taggable_array_on :tags
  belongs_to :user

  private def validate_tags
    if !tags.is_a?(Array) || tags.any?(&:blank?)
      errors.add(:tags, :invalid)
    end
  end

  private def unique_tags
    if tags.is_a?(Array)
      self.tags = tags.uniq.sort.reject(&:blank?)
    end
  end
  before_validation :unique_tags

  scope :tags_contains, ->(*values) {
    where("tags @> ARRAY[?]::varchar[]", values&.map(&:to_s))
  }


  def self.ransackable_attributes(_auth_object = nil)
    ["content", "create_from", "created_at", "created_on", "hostname", "id", "info", "lonlat", "price", "tags", "updated_at", "user_agent", "user_id"]
  end

  def self.ransackable_associations(_auth_object = nil)
    ["user"]
  end

  def self.ransackable_scopes(_auth_object = nil)
    %i[tags_contains]
  end

  include RansackerCreatedOn
end
