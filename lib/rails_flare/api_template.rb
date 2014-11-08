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
gem 'kaminari', version: '~> 0.16.1' # Pagnination
gem 'annotate', version: '~> 2.6.5'
after_bundle do
  run 'annotate'
end
gem "paranoia", version: "~> 2.0"
gem 'responders', version: '~> 2.0' # respond_to & respond_with
gem "active_model_serializers", version: "~> 0.9.0"

# Fix forgery protection for an API:
gsub_file 'app/controllers/application_controller.rb', /protect_from_forgery with: :exception/, 'protect_from_forgery with: :null_session'

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

##################
#    Options     #
##################

# Devise:
if yes? "Would you like to install Devise?"
  gem "devise", version: '~> 3.4.1'
  after_bundle do
    generate "devise:install"
  end

  user_model_name = ask("What would you like the user model to be called? [user]")
  user_model_name = "user" if user_model_name.blank?

  after_bundle do
    generate "devise", user_model_name
    generate "migration", "AddDeletedAtTo#{user_model_name.camelize} deleted_at:datetime:index"
  end
end

if yes? "Would you like to install EmberJS?"
  gem "jquery-rails", version: "~> 3.1.2"
  gem "ember-rails", version: "~> 0.15.0"
  gem "ember-source", version: "~> 1.8.1"
  gem 'coffee-rails', version: "~> 4.1.0"
  gem 'haml-rails', version: "~> 0.5.3"
  gem 'hamlbars', version: '~> 2.1'
  gem "bower-rails", version: "~> 0.9.2"

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

    file 'app/assets/javascripts/templates/application.js.hbs.hamlbars', <<-CODE
%div{:style => "width: 600px; border: 6px solid #eee; margin: 0 auto; padding: 20px; text-align: center; font-family: sans-serif;"}
  %img{:src => "http://emberjs.com/images/about/ember-productivity-sm.png", :style => "display: block; margin: 0 auto;"}/
  %h1 Welcome to Ember.js!
  %p
    You're running an Ember.js app on top of Ruby on Rails. To get started, replace this content
    (inside
    %code app/assets/javascripts/templates/application.js.hbs.hamlbars
    ) with your application's HTML.
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
    generate "migration", "AddAuthenticationTokenTo#{user_model_name.camelize} authentication_token:string"

    insert_into_file "app/models/#{user_model_name}.rb", before: "end\n" do <<-RUBY
  before_save :ensure_authentication_token

  def ensure_authentication_token
    if authentication_token.blank?
      self.authentication_token = generate_authentication_token
    end
  end

  private

  def generate_authentication_token
    loop do
      token = Devise.friendly_token
      break token unless User.where(authentication_token: token).first
    end
  end
    RUBY
    end
    generate :controller, "Sessions", "create", "--helper false --assets false --no-view-specs --skip-routes"
    run 'rm -rf app/views/sessions'
    gsub_file "app/controllers/sessions_controller.rb", "ApplicationController", "Devise::SessionsController"
    insert_into_file "app/controllers/sessions_controller.rb", after: "def create\n" do <<-'RUBY'
    respond_to do |format|
      format.html { super }
      format.json do
        self.resource = warden.authenticate!(auth_options)
        sign_in(resource_name, resource)
        data = {
          user_token: self.resource.authentication_token,
          user_email: self.resource.email
        }
        render json: data, status: 201
      end
    end
    RUBY
    end
    gsub_file "config/routes.rb", "devise_for :#{user_model_name.pluralize}", "devise_for :#{user_model_name.pluralize}, controllers: { sessions: 'sessions' }"
    insert_into_file "app/controllers/application_controller.rb", before: "end\n" do <<-RUBY
  before_filter :authenticate_user_from_token!

  private

  def authenticate_user_from_token!
    authenticate_with_http_token do |token, options|
      user_email = options[:user_email].presence
      user       = user_email && User.find_by_email(user_email)

      if user && Devise.secure_compare(user.authentication_token, token)
        sign_in user, store: false
      end
    end
  end
    RUBY
    end
    gsub_file "config/initializers/session_store.rb", /Rails.application.config.session_store (.*)$/, "Rails.application.config.session_store :disabled"
    rake "bower:install"
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
      rake "db:migrate", env: env
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
