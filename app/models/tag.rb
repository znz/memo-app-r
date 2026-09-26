# frozen_string_literal: true

# Tag owned by a user
class Tag < ApplicationRecord
  include Base58Uuid

  belongs_to :user
  has_many :reminder_tags, dependent: :destroy
  has_many :reminders, through: :reminder_tags

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :color, inclusion: { in: ThemeColor::COLORS }

  scope :enabled, -> { where(enabled: true) }
end
