require "test_helper"

class AuthenticatableTest < ActionController::TestCase
  class ProtectedController < ApplicationController
    before_action -> { authorize_roles!(:chef, :admin) }, only: :kitchen

    def index
      render json: { id: current_user.id }
    end

    def kitchen
      render json: { ok: true }
    end
  end

  tests ProtectedController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get "protected" => "authenticatable_test/protected#index"
      get "kitchen" => "authenticatable_test/protected#kitchen"
    end
  end

  def authenticate_as(user, token: JsonWebToken.encode(sub: user.id.to_s))
    @request.headers["Authorization"] = "Bearer #{token}"
  end

  test "rejects a request without a token" do
    get :index
    assert_response :unauthorized
    assert_equal "Bearer", response.headers["WWW-Authenticate"]
  end

  test "rejects a malformed authorization header" do
    @request.headers["Authorization"] = "Token abc"
    get :index
    assert_response :unauthorized
  end

  test "rejects an invalid token" do
    @request.headers["Authorization"] = "Bearer garbage"
    get :index
    assert_response :unauthorized
  end

  test "rejects an expired token" do
    authenticate_as users(:customer), token: JsonWebToken.encode(sub: users(:customer).id.to_s, expires_in: -1.minute)
    get :index
    assert_response :unauthorized
  end

  test "rejects a token for a user that no longer exists" do
    token = JsonWebToken.encode(sub: users(:customer).id.to_s)
    users(:customer).destroy
    authenticate_as nil, token: token
    get :index
    assert_response :unauthorized
  end

  test "accepts a valid token and exposes current_user" do
    authenticate_as users(:customer)
    get :index
    assert_response :success
    assert_equal users(:customer).id, response.parsed_body["id"]
  end

  test "allows a role listed in authorize_roles!" do
    authenticate_as users(:chef)
    get :kitchen
    assert_response :success
  end

  test "forbids a role not listed in authorize_roles!" do
    authenticate_as users(:customer)
    get :kitchen
    assert_response :forbidden
  end

  test "authentication runs before authorization" do
    get :kitchen
    assert_response :unauthorized
  end
end
