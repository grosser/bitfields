require "bundler/gem_tasks"
require "bump/tasks"
require "appraisal"

task :spec do
  sh "rspec spec/"
end

task :default do
  sh "bundle exec rake appraisal:install && bundle exec rake appraisal spec"
end
