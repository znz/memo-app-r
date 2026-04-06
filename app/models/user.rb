# frozen_string_literal: true

# User information
class User < ApplicationRecord
  include Base58Uuid

  devise(:confirmable, :database_authenticatable, :lockable, :recoverable, :rememberable, :timeoutable, :trackable, :validatable)
  has_many :memos, dependent: :destroy
end
