# frozen_string_literal: true

json.extract! memo, :id, :info, :content, :price, :category, :tags, :user_id, :create_from, :created_at, :updated_at
json.url memo_url(memo, format: :json)
