class <%= class_name %>
  include ::UseCase

  def initialize(model, auth_context)
    @model, @auth_context = model, auth_context
  end

  def call

  rescue => e
    raise ServiceFailedError, e
  end
end
