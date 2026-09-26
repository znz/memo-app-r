# frozen_string_literal: true

# Tag owned by a user
class Tag < ApplicationRecord
  include Base58Uuid

  belongs_to :user

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :color, inclusion: { in: ThemeColor::COLORS }

  scope :enabled, -> { where(enabled: true) }
end
