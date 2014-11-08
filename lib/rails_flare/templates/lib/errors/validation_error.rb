class ValidationError < RuntimeError

  attr_accessor :record

  def initialize(errors = nil, record = nil)
    @errors, self.record = errors, record
  end

  def to_s
    @errors.inspect
  end
end
