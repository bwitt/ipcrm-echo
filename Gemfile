source ENV['GEM_SOURCE'] || 'https://rubygems.org'

group :test do
  gem 'puppetlabs_spec_helper', require: false
  gem 'voxpupuli-test', '~> 15.0', require: false
end

group :system_tests do
  gem 'voxpupuli-acceptance', '~> 4.0', require: false
end

gem 'openvox', ENV.fetch('OPENVOX_GEM_VERSION', '~> 8.0'), require: false
