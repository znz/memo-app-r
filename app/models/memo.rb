# frozen_string_literal: true

# Memo data
class Memo < ApplicationRecord
  acts_as_taggable_array_on :tags
  belongs_to :user

  validates :user, presence: true
  private def validate_tags
    if !tags.is_a?(Array) || tags.any?(&:empty?)
      errors.add(:tags, :invalid)
    end
  end

  private def unique_tags
    self.tags = tags.uniq.sort.reject(&:empty?)
  end
  before_validation :unique_tags
end
