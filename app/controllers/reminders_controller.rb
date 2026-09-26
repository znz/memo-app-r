# frozen_string_literal: true

# Reminders of the current user
class RemindersController < ApplicationController
  before_action :set_reminder, only: %i[show edit update destroy]

  def index
    @reminders = current_user.reminders.includes(:tags).order(:name)
  end

  def show
  end

  def new
    @reminder = current_user.reminders.new(recurrence_preset: "none")
    @reminder.assign_attributes(location_params)
  end

  # The rule is shown as JSON to be edited
  def edit
    @reminder.recurrence_json = JSON.pretty_generate(@reminder.recurrence)
  end

  def create
    @reminder = current_user.reminders.new(reminder_params)
    if @reminder.save
      redirect_to @reminder, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @reminder.update(update_params)
      redirect_to @reminder, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @reminder.destroy!
    redirect_to reminders_path, notice: t(".success"), status: :see_other
  end

  private

  def set_reminder
    @reminder = current_user.reminders.find_uuid(params[:id])
  end

  def reminder_params
    params.expect(reminder: [
      :name, :description, :memo_template, :enabled, :starts_at, :due_at, :repeat_until,
      :recurrence_preset, :recurrence_json, :latitude, :longitude, :radius_m, memo_tags: [], tag_ids: []
    ])
  end

  # The edit form shows the current rule as JSON: a chosen preset wins over the JSON left as is
  def update_params
    attributes = reminder_params
    attributes.delete(:recurrence_json) if attributes[:recurrence_preset].present? && current_rule_json?(attributes[:recurrence_json])
    attributes
  end

  def current_rule_json?(json)
    JSON.parse(json.to_s) == @reminder.recurrence
  rescue JSON::ParserError
    false
  end

  # Location given by the link on a memo
  def location_params
    params.permit(reminder: %i[latitude longitude])[:reminder] || {}
  end
end
