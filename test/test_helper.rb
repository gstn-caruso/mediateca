ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "fileutils"

Dir[Rails.root.join("test/support/**/*.rb")].each { |file| require file }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Each worker gets its own database, but the portraits live on disk, and that
    # directory was shared. Two tests that photograph the same bytes land on the
    # same filename — content names the file — so one worker's write could
    # truncate the file another worker was busy serving, and the request answered
    # with an empty body. Give the directory the same isolation the database has.
    parallelize_setup do |worker|
      Rails.configuration.x.portraits_root = Rails.root.join("tmp/portraits-#{worker}").to_s
    end

    parallelize_teardown do
      FileUtils.rm_rf(Rails.configuration.x.portraits_root)
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module ActionDispatch
  class IntegrationTest
    include ListeningOverHttp
  end
end
