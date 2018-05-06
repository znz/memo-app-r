# frozen_string_literal: true

# User information
class User < ApplicationRecord
  devise(:confirmable, :database_authenticatable, :lockable, :recoverable, :registerable, :rememberable, :timeoutable, :trackable, :validatable)
  has_many :memos, dependent: :destroy
end
