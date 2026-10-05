# frozen_string_literal: true

# Reminders of the current user
class RemindersController < ApplicationController
  before_action :set_reminder, only: %i[show edit update destroy complete undo_complete]

  # By name, or with sort=board the actionable ones first in the order of the new memo page (without hiding any)
  def index
    @now = Time.current
    @sort = (params[:sort] == "board") ? "board" : "name"
    @reminders = current_user.reminders.includes(:tags).order(:name)
    @reminders = ReminderBoard.new(@reminders, now: @now, hide_by_tags: false).all_in_order if @sort == "board"
  end

  def show
  end

  def new
    @reminder = current_user.reminders.new(recurrence_preset: "none")
    @reminder.assign_attributes(location_params)
  end

  def edit
    fill_recurrence_json
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
      fill_recurrence_json
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @reminder.destroy!
    redirect_to reminders_path, notice: t(".success"), status: :see_other
  end

  # Goes to a new memo prefilled from the reminder, with a button to undo in the flash
  def complete
    @reminder.complete!
    redirect_to new_memo_path(reminder_id: @reminder.to_param), notice: t(".success", name: @reminder.name),
      flash: { undo: { "path" => undo_complete_reminder_path(@reminder), "completed_at" => @reminder.last_completed_at.iso8601(6) } }
  end

  # From the button in the flash, on the list or on the detail page
  def undo_complete
    if @reminder.undo_complete!(params[:completed_at])
      redirect_to new_memo_path, notice: t(".success", name: @reminder.name)
    else
      redirect_to new_memo_path, alert: t(".failure", name: @reminder.name)
    end
  end

  private

  def set_reminder
    @reminder = current_user.reminders.find_uuid(params[:id])
  end

  def reminder_params
    params.expect(reminder: [
      :name, :description, :memo_template, :enabled, :starts_at, :due_at, :prioritize_at, :repeat_until,
      :recurrence_preset, :recurrence_json, :last_completed_at, :latitude, :longitude, :radius_m, memo_tags: [], tag_ids: []
    ])
  end

  # The edit form shows the saved rule as JSON to be edited (unless JSON is given)
  def fill_recurrence_json
    @reminder.recurrence_json = JSON.pretty_generate(@reminder.recurrence_in_database) if @reminder.recurrence_json.blank?
  end

  # The edit form shows the current rule as JSON: a chosen preset wins over the JSON left as is
  def update_params
    attributes = reminder_params
    attributes.delete(:recurrence_json) if attributes[:recurrence_preset].present? && current_rule_json?(attributes[:recurrence_json])
    attributes.delete(:last_completed_at) if attributes.key?(:last_completed_at) && current_last_completed_at?(attributes[:last_completed_at])
    attributes
  end

  # The input has no seconds: the saved time left as is would be truncated to the minute (and no longer undoable)
  def current_last_completed_at?(value)
    saved = @reminder.last_completed_at
    saved.present? && Reminder.type_for_attribute(:last_completed_at).cast(value) == saved.beginning_of_minute
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
