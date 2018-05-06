Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
  g.helper       false
  g.javascripts  false
  g.stylesheets  false
end
