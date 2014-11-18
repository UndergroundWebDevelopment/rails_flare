module UWD
  module SecurityHelpers
    def secure_random
      SecureRandom.urlsafe_base64(15).tr('lIO0', 'sxyz')
    end

    def secure_compare(a, b)
      return false if a.blank? || b.blank? || a.bytesize != b.bytesize
      l = a.unpack "C\#{a.bytesize}"

      res = 0
      b.each_byte { |byte| res |= byte ^ l.shift }
      res == 0
    end
  end
end
