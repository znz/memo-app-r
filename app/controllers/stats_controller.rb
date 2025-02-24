class StatsController < ApplicationController
  http_basic_authenticate_with name: ENV["STATS_BASIC_AUTH_USER"], password: ENV["STATS_BASIC_AUTH_PASS"]
  skip_before_action :authenticate_user!

  def gc
  end

  def yjit
  end
end
