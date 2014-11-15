def source_paths
  [File.expand_path(File.dirname(__FILE__))]
end

def db_start_command
  @db_start_command || raise("DB Start Command not yet set!")
end

def db_start_command= (val)
  @db_start_command = val
end

def with_db(options = {})
  options[:sleep] ||= 3
  db_pid = fork do
    exec db_start_command
  end

  sleep options[:sleep]
  begin
    yield
  ensure
    Process.kill("TERM", db_pid)
  end
end

def db_type
  db_type = nil
  in_root do
    File.readlines("config/database.yml").each do |line|
      matches = line.match(/adapter: ([a-zA-Z0-9]+)/)
      if matches.present?
        db_type = matches.captures.first
        break
      end
    end
  end
  db_type.to_sym
end

unless app_name == "test_app"
  if yes? "Create tmuxinator script for #{app_name}?"
    template "templates/tmuxinator.yml.erb", File.expand_path("~/.tmuxinator/#{app_name}.yml")
  end
end

insert_into_file "app/controllers/application_controller.rb", before: "end\n" do 
  "  private\n"
end

########################
#   Database Scripts   #
########################

# Uncomment bcrypt gem:
uncomment_lines 'Gemfile', /gem 'bcrypt'/
gsub_file 'config/database.yml', /password:$/, 'password: root'

if db_type == :postgresql
  # Postgres startup script:
  copy_file "templates/bin/local_postgres.sh", "bin/local_postgres.sh"
  run "chmod +x bin/local_postgres.sh"
  append_to_file ".gitignore", "vendor/postgresql/*"

  self.db_start_command = "bin/local_postgres.sh"
else
  self.db_start_command = "mysqld"
end

gem "sequel-rails", version: "~> 0.9.5"
gem "simple_repository"
comment_lines "config/application.rb", /active_record/
comment_lines "config/environments/development.rb", /active_record/
comment_lines "config/environments/test.rb", /active_record/
comment_lines "config/environments/production.rb", /active_record/
after_bundle do
  generate "simple_repository:install"
end

# Over-ride sequel generators:
# directory "templates/lib/generators/sequel", "lib/generators/sequel"


##################
#  Server Setup  #
##################
# Unicorn:
gem "unicorn", version: "~> 4.8.3"
run "mkdir -p tmp/pids/"

# Unicorn config file:
copy_file "templates/config/unicorn.rb", "config/unicorn.rb"

##################
# Proces Manager #
##################
# Foreman:
gem 'foreman', version: '~> 0.75'
create_file "Procfile" do
  file_lines = []
  file_lines << "db: #{db_start_command}"
  file_lines << "web: bundle exec unicorn_rails -c ./config/unicorn.rb"
  file_lines.join("\n")
end

################################
# Common Gems & General Config #
################################

gem 'pundit', version: '~> 0.3.0'
after_bundle do
  generate "pundit:install"
  inject_into_file "app/controllers/application_controller.rb", after: "class ApplicationController < ActionController::Base\n" do <<-'RUBY'
  include Pundit
  RUBY
  end
end
gem 'reform', version: '~> 1.2.1' # Advanced form objects
gem "virtus", version: "~> 1.0"
gem "virtus-dirty_attribute", version: "~> 0.1"
gem 'annotate', version: '~> 2.6.5'
after_bundle do
  run 'annotate'
end
# gem "paranoia", version: "~> 2.0"
gem 'responders', version: '~> 2.0' # respond_to & respond_with
gem "active_model_serializers", version: "~> 0.9.0"

# Fix forgery protection for an API:
gsub_file 'app/controllers/application_controller.rb', /protect_from_forgery with: :exception/, 'protect_from_forgery with: :null_session'

# Configure rails scaffold to be more in-line with API development:
# NOTE: I know the indenting looks off, but it works.
application do <<-'RUBY'
config.generators do |g|
      g.template_engine false
      g.test_framework  :rspec, fixture: false
      g.stylesheets     false
      g.javascripts     false
      g.helper          false
    end
RUBY
end

# Install use-case generator:
directory "templates/lib/generators/use_case", "lib/generators/use_case"
# Install use-case mixin:
directory "templates/app/use_cases/concerns", "app/use_cases/concerns"
application 'config.autoload_paths += %W(#{config.root}/app/use_cases/concerns)'

# Basic exceptions:
directory "templates/lib/errors", "lib/errors"
application 'config.autoload_paths += %W(#{config.root}/lib/errors)'
inject_into_class "app/controllers/application_controller.rb", "ApplicationController" do <<-'RUBY'

  rescue_from ValidationError, with: :invalid_request
  rescue_from UnauthorizedError, with: :unauthorized_request
  rescue_from ServiceFailedError, with: :service_failed

RUBY
end

insert_into_file "app/controllers/application_controller.rb", after: "private\n" do <<-'RUBY'

  def service_failed(error)
    return render json: {errors: [error.to_s]}, status: :internal_server_error
  end

  def unauthorized_request(error)
    return render json: {errors: [error.to_s]}, status: :unauthorized
  end

  def invalid_request(error)
    return render json: {errors: [error.to_s]}, status: :bad_request
  end

  def not_found(error)
    return render json: {errors: [error.to_s]}, status: :not_found
  end

RUBY
end

if yes? "Would you like to install Warden and configure Authentication?"
  auth_model_name = ask "What should the auth (user) model be called? Default: user"
  auth_model_name = auth_model_name.present? ? auth_model_name : "user"
  auth_model_path = auth_model_name.underscore
  auth_model_class = auth_model_name.camelize
  puts "Creating auth for model '#{auth_model_class}'"

  # Install and configure warden:
  gem 'rails_warden'

  inject_into_class "app/controllers/application_controller.rb", "ApplicationController" do <<-'RUBY'

  def unauthorized
    return unauthorized_request("Unauthorized")
  end
  RUBY
  end

  template "templates/config/initializers/warden.rb", "config/initializers/warden.rb"

  after_bundle do
    # NOTE: Running this with "no migration" as initially we're using a memory
    # store... finalizing the choice of data stores can (and should) come later.
    generate "scaffold #{auth_model_path} id:integer given_name:string family_name email:string password_digest:string api_token:string --no-migration"

    inject_into_class "app/models/#{auth_model_path}.rb", "#{auth_model_class}" do <<-'RUBY'
  include ActiveModel::SecurePassword

  has_secure_password
    RUBY
    end

    inject_into_class "app/repositories/#{auth_model_path}_repo.rb", "#{auth_model_class}Rep" do <<-RUBY
    class << self
      def find_by_email(email)
        query #{auth_model_class}WithEmail.new(email)
        # all.select {|#{auth_model_path}| #{auth_model_path}.email == email}.first
      end

      def find_by_api_token(api_token)
        query #{auth_model_class}WithApiToken.new(api_token)
        # all.select {|#{auth_model_path}| #{auth_model_path}.api_token == api_token}.first
      end
    end
    RUBY
    end

    append_to_file "app/repositories/#{auth_model_path}_repo.rb" do <<-RUBY

#{auth_model_class}WithEmail = Struct.new(:email)
#{auth_model_class}WithApiToken = Struct.new(:api_token)
    RUBY
    end

    create_file "app/adapters/memory_adapter.rb" do <<-RUBY
class MemoryAdapter < SimpleRepository::MemoryAdapter
  def query_#{auth_model_path}_with_email(klass, q)
    all(klass).find do |#{auth_model_path}|
      #{auth_model_path}.email == q.email
    end
  end

  def query_#{auth_model_path}_with_api_token(klass, q)
    all(klass).find do |#{auth_model_path}|
      #{auth_model_path}.api_token == q.api_token
    end
  end
end
    RUBY
    end

    append_to_file "config/initializers/simple_repository.rb" do <<-'RUBY'

SimpleRepository.repo.register :memory, MemoryAdapter.new
SimpleRepository.repo.use :memory
    RUBY
    end
  end
end

###########################
#   Testing & Dev Tools   #
###########################

gem_group :development, :test do
  # RSpec for tests:
  gem "rspec-rails", version: "~> 3.0.0"
  after_bundle do
    generate "rspec:install"
  end

  # Faker
  gem 'faker', version: '~> 1.4.3'

  # Jazz hands brings pry, pretty_print, and more
  # to rails:
  gem 'jazz_hands',                   # Make rails console a lot better
    github: 'jkrmr/jazz_hands',       # Fork that has pry 0.10.0
    branch: 'byebug_and_updated_pry'  # Needed so we can use pry-byebug

  # Capistrano 3 for deployment:
  gem 'capistrano', version: '~> 3.2.0'
  gem 'capistrano-rails', version: '1.1.1'
  after_bundle do
    run 'bundle exec cap install'
    insert_into_file 'Capfile', after: "require 'capistrano/deploy'\n" do
      "\n# Include rails deploy tasks\nrequire 'capistrano/rails'\n"
    end
  end
end

gem_group :development, :staging do
  # MailSafe protects against sending real emails in development & staging
  # environments.
  gem 'mail_safe', version: '~> 0.3.3'
end

# Create staging environment
run 'cp config/environments/production.rb config/environments/staging.rb'

# Install lograge, enable it for staging & production.
gem 'lograge', version: '0.3.0'
application 'config.lograge.enabled = true', env: ["production", "staging"]

##################
#    Options     #
##################

if yes? "Would you like to install EmberJS?"
  gem "jquery-rails", version: "~> 3.1.2"
  gem "ember-rails", version: "~> 0.15.0"
  gem "ember-source", version: "~> 1.8.1"
  gem 'coffee-rails', version: "~> 4.1.0"
  gem 'coffee-rails-source-maps', version: '~> 1.4.0', group: "development"
  gem 'haml-rails', version: "~> 0.5.3"
  gem 'hamlbars', version: '~> 2.1'
  gem "bower-rails", version: "~> 0.9.2"
  gem 'emblem-rails', version: "~> 0.2.1"

  after_bundle do
    generate "ember:bootstrap", "-g --javascript-engine coffee"
    
    # Configure the app to serve Ember.js and app assets from an AssetsController
    generate :controller, "Assets", "index"
    run "rm app/views/assets/index.html.haml"
    file 'app/views/assets/index.html.haml', <<-CODE
!!!
%html
  %head
    %title Test App
    = stylesheet_link_tag    "application", :media => "all"
    = csrf_meta_tags
  %body
    = javascript_include_tag "application"
    CODE

    remove_file 'app/assets/javascripts/templates/application.handlebars'

    file 'app/assets/javascripts/templates/application.emblem', <<-CODE
div style="width: 600px; border: 6px solid #eee; margin: 0 auto; padding: 20px; text-align: center; font-family: sans-serif;"
  img src="http://emberjs.com/images/about/ember-productivity-sm.png" style="display: block; margin: 0 auto;"
  h1 Welcome to Ember.js!
  p 
    | You're running an Ember.js app on top of Ruby on Rails. To get started, replace this content (inside
    code app/assets/javascripts/templates/application.emblem
    | ) with your application's HTML.
    CODE

    run "rm -rf app/views/layouts"
    route "root :to => 'assets#index'"

    # Generate a default serializer that is compatible with ember-data
    generate :serializer, "application", "--parent", "ActiveModel::Serializer"
    inject_into_class "app/serializers/application_serializer.rb", 'ApplicationSerializer' do
      "  embed :ids, :include => true\n"
    end

    generate "bower_rails:initialize"
    append_to_file "Bowerfile" do <<-RUBY
asset 'ember-simple-auth'
    RUBY
    end

    gsub_file "config/initializers/session_store.rb", /Rails.application.config.session_store (.*)$/, "Rails.application.config.session_store :disabled"
    rake "bower:install"

    # Install bootstrap to fascilitate Ember app development:
    gem 'bootstrap-sass', version: '~> 3.3.0'
    gem 'autoprefixer-rails', version: '~> 3.1.2.0'
    run "rm app/assets/stylesheets/application.css"
    create_file "app/assets/stylesheets/application.css.sass" do <<-'RUBY'
@import "bootstrap-sprockets"
@import "bootstrap"
    RUBY
    end

    insert_into_file "app/assets/javascripts/application.js.coffee", after: "#= require jquery\n" do <<-'RUBY'
#= require bootstrap-sprockets
    RUBY
    end
  end
end

############
# DB Setup #
############
after_bundle do
  with_db do
    ['development', 'test'].each do |env|
      # Special case for the test app, drop existing DB's before re-creating.
      # We don't want to do this for all apps, or we might over-right another
      # app's DB by mistake.
      rake "db:drop", env: env if app_name == "test_app"
      rake "db:create", env: env

      # Only bother running migrations if we've setup any:
      if Dir.exist? "db/migrate"
        rake "db:migrate", env: env
      end
    end
  end
end

##################
# Initialize GIT #
##################
after_bundle do
  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit' }
end
