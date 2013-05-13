["2.3", "3.0", "3.1", "3.2"].each do |version|
  appraise "activerecord_#{version}" do
    gem "activerecord", "~> #{version}.0"
  end
end

appraise "activerecord_4.0" do
  gem "activerecord", "~> 4.0.0.rc"
end
