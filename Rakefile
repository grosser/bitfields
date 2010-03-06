require 'spec/rake/spectask'
Spec::Rake::SpecTask.new {|t| t.spec_opts = ['--color']}

task :default do
  # test with 2.x
  puts `VERSION='~>2' rake spec`

  # gem 'activerecord', '>=3' did not work for me, but just require gets the right version...
  require 'active_record'
  if ActiveRecord::VERSION::MAJOR >= 3
    puts `rake spec`
  else
    'install rails 3 to get full test coverage...'
  end
end

begin
  require 'jeweler'
  project_name = 'bitfields'
  Jeweler::Tasks.new do |gem|
    gem.name = project_name
    gem.summary = "Save migrations and columns by storing multiple booleans in a single integer."
    gem.email = "grosser.michael@gmail.com"
    gem.homepage = "http://github.com/grosser/#{project_name}"
    gem.authors = ["Michael Grosser"]
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler, or one of its dependencies, is not available. Install it with: sudo gem install jeweler"
end
