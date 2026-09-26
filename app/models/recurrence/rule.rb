# frozen_string_literal: true

# Base class of repeat rules
class Recurrence::Rule
  KEYS = [].freeze

  def self.type = name.demodulize.underscore

  def self.from_hash(attributes)
    unknown_key = (attributes.keys - self::KEYS).first
    raise Recurrence::InvalidRule.new(:unknown_key, key: unknown_key) if unknown_key

    new(attributes)
  end

  def self.new(...) = super.freeze

  def initialize(attributes)
    @values = attributes
  end

  delegate :type, to: :class

  def to_h = { "type" => type, **@values }

  private def with_detail(base, detail) = detail ? "#{base} #{detail}" : base

  private def positive_integer(key, error_key, default: nil)
    return default unless @values.key?(key)

    value = @values[key]
    raise Recurrence::InvalidRule, error_key unless value.is_a?(Integer) && value.positive?

    value
  end
end
