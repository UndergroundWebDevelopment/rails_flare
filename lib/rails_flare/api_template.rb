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

##################
#    CLEANUP     #
##################

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
gem "unicorn"
run "mkdir -p tmp/pids/"

# Unicorn config file:
copy_file "templates/config/unicorn.rb", "config/unicorn.rb"

##################
# Proces Manager #
##################
# Foreman:
gem 'foreman'
create_file "Procfile" do
  file_lines = []
  file_lines << "db: #{db_start_command}"
  file_lines << "web: bundle exec unicorn_rails -c ./config/unicorn.rb"
  file_lines.join("\n")
end

###########################
#   Testing & Dev Tools   #
###########################

# Add rspec-rails to the Gemfile
gem_group :development, :test do
  gem "rspec-rails", version: "~> 3.0.0"
end

# Run rspec generator:
after_bundle do
  generate "rspec:install"
end

##################
#    Options     #
##################

# Devise:
if yes?("Would you like to install Devise?")
  gem "devise"
  after_bundle do
    generate "devise:install"
  end

  model_name = ask("What would you like the user model to be called? [user]")
  model_name = "user" if model_name.blank?

  after_bundle do
    generate "devise", model_name
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
