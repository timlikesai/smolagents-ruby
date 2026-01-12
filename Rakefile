require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "yard"

RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new

YARD::Rake::YardocTask.new(:doc) do |t|
  t.files = ["lib/**/*.rb"]
  t.options = ["--output-dir", "doc"]
end

namespace :doc do
  desc "Generate documentation and open in browser"
  task open: :doc do
    sh "open doc/index.html" if RUBY_PLATFORM.include?("darwin")
  end

  desc "Generate documentation and serve locally"
  task :server do
    sh "yard server --reload"
  end
end

task default: %i[spec rubocop]
