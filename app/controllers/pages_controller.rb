# frozen_string_literal: true

# pages
class PagesController < ApplicationController
  def about
  end

  def ip
    render plain: request.remote_ip
  end
end
