# frozen_string_literal: true

# User information
class User < ApplicationRecord
  devise %i[
    confirmable
    database_authenticatable
    lockable
    omniauthable
    recoverable
    registerable
    ememberable
    timeoutable
    trackable
    validatable
  ]
end
