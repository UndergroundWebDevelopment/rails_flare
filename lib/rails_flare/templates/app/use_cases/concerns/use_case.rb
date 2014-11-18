module UseCase 
  extend ActiveSupport::Concern
  included do
 
    include Pundit

    def self.call(*args, &block)
      new(*args).call(&block)
    end
  end
end
