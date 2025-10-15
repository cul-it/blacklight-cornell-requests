# require 'rspec/autorun'
require 'rails_helper'
require 'rubygems'
require 'blacklight'
require 'webmock/rspec'
require 'vcr'
require 'dotenv'
require 'simplecov'

Dotenv.load
SimpleCov.start

# ENV['RAILS_ENV'] ||= 'test'





#   Dir[File.join(ENGINE_RAILS_ROOT, "spec/support/**/*.rb")].each {|f| require f }

#ENGINE_RAILS_ROOT=File.join(File.dirname(__FILE__), '../')
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }


RSpec.configure do |config|
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"
  # config.use_transactional_fixtures = true
  # config.infer_base_class_for_anonymous_controllers = false
  config.mock_with :rspec
  config.order = "random"
end
