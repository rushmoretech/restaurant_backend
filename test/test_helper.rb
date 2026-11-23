ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Authorization header for requests made as the given user.
    def auth_headers(user)
      { "Authorization" => "Bearer #{JsonWebToken.encode(sub: user.id.to_s)}" }
    end
  end
end
