# frozen_string_literal: true

# User information
class User < ApplicationRecord
  devise(*%i[
    confirmable
    database_authenticatable
    lockable
    recoverable
    registerable
    rememberable
    timeoutable
    trackable
    validatable
  ])
end
