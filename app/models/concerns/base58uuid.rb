# frozen_string_literal: true

module Base58uuid
  def to_param
    return id unless id
    return id if id[14] == "4"
    encode58_from_uuid(id)
  end

  def self.included(base)
    def base.find_uuid(param)
      if param.is_a?(String) && param.length == 22
        param = Base58uuid.decode58_to_uuid(param)
      end
      find(param)
    end
  end

  module_function

  BASE58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

  def decode58_to_uuid(encoded, alphabet: BASE58_ALPHABET)
    if encoded.length != 22
      raise "Expected Base58 string of length 22, but received string of length #{encoded.length}: #{encoded}"
    end
    encoded.each_char.inject(0) { |s, c| s * 58 + alphabet.index(c) }.to_s(16).rjust(32, "0")
  end

  def encode58_from_uuid(uuid, alphabet: BASE58_ALPHABET)
    hex = uuid.delete("-")
    if hex.length != 32
      raise "Invalid UUID length: expected 32 characters (excluding hyphens), got #{hex.length} characters in #{uuid}"
    end
    num = Integer(hex, 16)
    a = Array.new(22, alphabet[0])
    i = -1
    while num > 0
      num, mod = num.divmod(58)
      a[i] = alphabet[mod]
      i -= 1
    end
    a.join("")
  end
end
