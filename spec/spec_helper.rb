require 'rubygems'
require 'webmock/rspec'
require 'webmock/api'
# Configure Rails Environment
require File.expand_path('../dummy/config/environment.rb',  __FILE__)

require 'rspec/rails'
require 'rspec/autorun'
require 'ffaker'


# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].each { |f| require f }

# Requires factories defined in spree_core
require 'spree/testing_support/factories'
require 'spree/testing_support/controller_requests'
require 'spree/testing_support/authorization_helpers'
require 'spree/testing_support/url_helpers'


# Rails engines something like this to make Factory Girl work

Dir[File.join(File.dirname(__FILE__), 'factories/**/*.rb')].each { |f| require f }



RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods
  config.include Spree::TestingSupport::UrlHelpers
  config.include Spree::TestingSupport::AuthorizationHelpers::Controller
  config.include Spree::TestingSupport::ControllerRequests, :type => :controller

  config.mock_with :rspec
  config.color = true
  config.use_transactional_fixtures = true

  config.fail_fast = ENV['FAIL_FAST'] || false

  config.order = "random"
end
