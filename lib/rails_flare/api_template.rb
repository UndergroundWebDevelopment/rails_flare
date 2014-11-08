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
gem "roar-rails", version: "~> 0.1.6" # ROAR representers & parsers.
application "config.representer.represented_formats = [:hal, :json]"
after_bundle do
  inject_into_file "app/controllers/application_controller.rb", after: "class ApplicationController < ActionController::Base\n" do <<-'RUBY'
  include Roar::Rails::ControllerAdditions
  respond_to :json, :hal
  RUBY
  end
end

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
  after_bundle do
    run 'bundle exec cap install'
  end
end

gem_group :development, :staging do
  # MailSafe protects against sending real emails in development & staging
  # environments.
  gem 'mail_safe', version: '~> 0.3.3'
end

# Run rspec generator:

##################
#    Options     #
##################

# Devise:
if yes?("Would you like to install Devise?")
  gem "devise", version: '~> 3.4.1'
  after_bundle do
    generate "devise:install"
  end

  model_name = ask("What would you like the user model to be called? [user]")
  model_name = "user" if model_name.blank?

  after_bundle do
    generate "devise", model_name
    generate "migration", "AddDeletedAtTo#{model_name.camelize} deleted_at:datetime:index"
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
