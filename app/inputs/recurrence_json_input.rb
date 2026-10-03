# frozen_string_literal: true

# Text input of the recurrence JSON that also shows the errors of recurrence (the rule built from the JSON)
class RecurrenceJsonInput < SimpleForm::Inputs::TextInput
  protected def errors_on_attribute = super + object.errors[:recurrence]

  protected def full_errors_on_attribute = super + object.errors.full_messages_for(:recurrence)
end
