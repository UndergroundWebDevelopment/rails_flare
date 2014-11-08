class ServiceFailedError < RuntimeError
  def initialize(exception = nil)
    if exception.nil? || exception.is_a?(String)
      super exception
    else
      @exception = exception
      super exception.message
    end
  end

  def backtrace
    if @exception
      @exception.backtrace
    else
      super
    end
  end
end
