#!/bin/bash

function run_rspec () {
  echo "Running rspec for ActiveRecord $activerecord_version"
  printf '=%.0s' {1..100}
  echo "\n"

  BUNDLE_GEMFILE=gemfiles/activerecord_$activerecord_version.gemfile bundle install &&
  BUNDLE_GEMFILE=gemfiles/activerecord_$activerecord_version.gemfile bundle exec rspec
}

if [ $# -eq 0 ]
  then
    for f in ./gemfiles/activerecord*.gemfile; do
      activerecord_version=$(echo $f | egrep -o '[[:digit:]].[[:digit:]]' | head -n1)
      run_rspec
    done
else
  for activerecord_version; do
    run_rspec
  done
fi
