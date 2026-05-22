# frozen_string_literal: true

begin
  require 'bundler/setup'
rescue Bundler::GemfileNotFound, Bundler::GemNotFound, LoadError
  # Bundler not available or gems not installed, load gems manually
end

require 'lpsolver'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
