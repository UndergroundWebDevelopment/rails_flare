module UseCase 
  extend ActiveSupport::Concern
  included do
    def self.call(*args, &block)
      new(*args).call(&block)
    end
  end
end
