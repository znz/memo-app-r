# frozen_string_literal: true

# Tags of the current user
class TagsController < ApplicationController
  before_action :set_tag, only: %i[edit update destroy]

  def index
    @tags = current_user.tags.order(:name)
  end

  def new
    @tag = current_user.tags.new
  end

  def edit
  end

  def create
    @tag = current_user.tags.new(tag_params)
    if @tag.save
      redirect_to tags_path, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @tag.update(tag_params)
      redirect_to tags_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @tag.destroy!
    redirect_to tags_path, notice: t(".success"), status: :see_other
  end

  private

  def set_tag
    @tag = current_user.tags.find_uuid(params[:id])
  end

  def tag_params
    params.expect(tag: %i[name color enabled])
  end
end
