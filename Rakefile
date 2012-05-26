task :spec do
  sh "rspec spec"
end

task :default do
  sh "AR=2.3.14 && (bundle || bundle install) && bundle exec rake spec"
  sh "AR=3.0.12 && (bundle || bundle install) && bundle exec rake spec"
  sh "AR=3.1.4 && (bundle || bundle install) && bundle exec rake spec"
  sh "AR=3.2.3 && (bundle || bundle install) && bundle exec rake spec"
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = 'bitfields'
    gem.summary = "Save migrations and columns by storing multiple booleans in a single integer."
    gem.email = "grosser.michael@gmail.com"
    gem.homepage = "http://github.com/grosser/#{gem.name}"
    gem.authors = ["Michael Grosser"]
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler, or one of its dependencies, is not available. Install it with: sudo gem install jeweler"
end
