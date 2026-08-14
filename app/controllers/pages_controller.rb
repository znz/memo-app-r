# frozen_string_literal: true

# pages
class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:ip]

  def about
  end

  def ip
    render plain: request.remote_ip
  end
end
