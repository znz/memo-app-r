enabled = RubyVM::YJIT.enabled?
json.enabled enabled
if enabled
  json.runtime_stats do
    RubyVM::YJIT.runtime_stats.each do |k, v|
      json.set! k, v
    end
  end
end
