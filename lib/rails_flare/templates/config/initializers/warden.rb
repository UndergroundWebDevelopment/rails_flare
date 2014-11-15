Rails.configuration.middleware.use RailsWarden::Manager do |manager|
  manager.default_strategies [:email_and_password, :token]
  manager.failure_app = ->(env) { ApplicationController.action(:unauthorized).call(env) }
end

# Setup Session Serialization
class Warden::SessionSerializer
  def serialize(record)
    [record.class.name, record.id]
  end

  def deserialize(keys)
    klass, id = keys
    klass.find(:first, :conditions => { :id => id })
  end
end

# Declare your strategies here
Warden::Strategies.add(:email_and_password) do
  def authenticate!
    email = extract_value_from_params :email
    password = extract_value_from_params :password

    user = UserRepo.find_by_email(email)
    if user
      begin
        if user.authenticate(password)
          success! user
        else
          failure_condition
        end
      rescue
        failure_condition
      end
    end
  end

  private

  def failure_condition
    fail! "Invalid user or password!"
  end

  def extract_value_from_params(key)
    case key
    when String, Symbol
      keys = key.to_s.split(":")
      if keys.size == 1
        params[keys.first]
      else
        keys.inject(params){|p,k| p[k]}
      end
    when Proc
      instance_eval(&key)
    end
  end
end

Warden::Strategies.add(:token) do
  def authenticate!
    if request.authorization && request.authorization =~ /^Basic (.*)/m
      token = Base64.decode64($1).split(/:/, 2)
      user = UserRepo.find_by_api_token(token)
      if user
        success! user
      end
    end
  end
end
