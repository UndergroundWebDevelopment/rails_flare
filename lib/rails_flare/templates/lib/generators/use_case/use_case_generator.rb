class UseCaseGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('../templates', __FILE__)

  desc "Creates a UseCase class at app/use_cases"

  def copy_use_case_file
    template "use_case.rb", "app/use_cases/#{file_path}.rb"
  end

  def copy_use_case_test
    template "use_case_spec.rb", "spec/use_cases/#{file_path}_spec.rb"
  end
end
