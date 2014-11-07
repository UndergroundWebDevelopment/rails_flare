def source_paths
  [File.expand_path(File.dirname(__FILE__))]
end

##################
#    CLEANUP     #
##################

######################
#   Database Setup   #
######################

db = nil
in_root do
  File.readlines("config/database.yml").each do |line|
    matches = line.match(/adapter: ([a-zA-Z0-9]+)/)
    if matches.present?
      db = matches.captures.first
      break
    end
  end
end

if db == 'postgresql'
  # Postgres startup script:
  copy_file "templates/bin/local_postgres.sh", "bin/local_postgres.sh"
  run "chmod +x bin/local_postgres.sh"
  append_to_file ".gitignore", "vendor/postgresql/*"

  db_start_script = "bin/local_postgres.sh"
else
  db_start_script = "mysql -uroot -proot -A"
end

db_pid = fork do
  exec db_start_script
end

sleep 3
rake "db:create"
Process.kill("TERM", db_pid)

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
  file_lines << "db: #{db_start_script}"
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

##################
# Initialize GIT #
##################
after_bundle do
  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit' }
end
