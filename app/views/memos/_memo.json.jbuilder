# frozen_string_literal: true

json.extract! memo, :id, :info, :content, :price, :tags, :user_id, :create_from, :hostname, :user_agent, :lonlat, :created_at, :updated_at
json.url memo_url(memo, format: :json)
