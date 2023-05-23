# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "./app"
require "rspec/core"
require "rspec/core/rake_task"

desc "Lint ruby files"
task :lint do
  sh "bundle exec rubocop --parallel lib spec"
end

desc "Run all specs in spec directory (excluding plugin specs)"
RSpec::Core::RakeTask.new(:spec)

task default: %i[spec lint]
