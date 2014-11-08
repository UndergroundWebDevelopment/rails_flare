class <%= class_name %>
  include ::UseCase

  def initialize(data_hash, auth_context)
    @data_hash, @auth_context = data_hash, auth_context
  end

  def call

  rescue => e
    raise ServiceFailedError, e
  end
end
