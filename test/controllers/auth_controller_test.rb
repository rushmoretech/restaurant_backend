require "test_helper"

class AuthControllerTest < ActionDispatch::IntegrationTest
  def signup_params(**overrides)
    {
      first_name: "Elena",
      last_name: "Radu",
      email: "elena@example.com",
      password: "password123"
    }.merge(overrides)
  end

  # --- signup ---------------------------------------------------------------

  test "signup creates a customer and returns a token" do
    assert_difference "User.count", 1 do
      post signup_url, params: signup_params, as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal "elena@example.com", body["user"]["email"]
    assert_equal "customer", body["user"]["role"]
    assert_equal User.find_by(email: "elena@example.com").id.to_s, JsonWebToken.decode(body["token"])[:sub]
  end

  test "signup ignores a requested role" do
    post signup_url, params: signup_params(role: "admin"), as: :json

    assert_response :created
    assert_equal "customer", User.find_by(email: "elena@example.com").role
  end

  test "signup never exposes the password digest" do
    post signup_url, params: signup_params, as: :json

    assert_no_match(/password/, response.parsed_body["user"].keys.join)
  end

  test "signup rejects invalid data" do
    assert_no_difference "User.count" do
      post signup_url, params: signup_params(email: "nope", password: "short"), as: :json
    end

    assert_response :unprocessable_content
    assert_not_empty response.parsed_body["errors"]
  end

  test "signup rejects a duplicate email regardless of case" do
    post signup_url, params: signup_params(email: users(:customer).email.upcase), as: :json

    assert_response :unprocessable_content
  end

  # --- login ----------------------------------------------------------------

  test "login returns a token for valid credentials" do
    post login_url, params: { email: "ana@example.com", password: "password123" }, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal users(:customer).id.to_s, JsonWebToken.decode(body["token"])[:sub]
    assert_equal "customer", body["user"]["role"]
  end

  test "login is case and whitespace insensitive on email" do
    post login_url, params: { email: "  ANA@Example.com ", password: "password123" }, as: :json

    assert_response :success
  end

  test "login rejects a wrong password" do
    post login_url, params: { email: "ana@example.com", password: "wrong" }, as: :json

    assert_response :unauthorized
    assert_nil response.parsed_body["token"]
  end

  test "login rejects an unknown email with the same message as a wrong password" do
    post login_url, params: { email: "ana@example.com", password: "wrong" }, as: :json
    wrong_password_error = response.parsed_body["error"]

    post login_url, params: { email: "nobody@example.com", password: "password123" }, as: :json

    assert_response :unauthorized
    assert_equal wrong_password_error, response.parsed_body["error"]
  end

  test "login handles missing parameters" do
    post login_url, params: {}, as: :json

    assert_response :unauthorized
  end

  # --- me -------------------------------------------------------------------

  test "me returns the authenticated user" do
    get me_url, headers: auth_headers(users(:chef))

    assert_response :success
    user = response.parsed_body["user"]
    assert_equal users(:chef).id, user["id"]
    assert_equal "chef", user["role"]
    assert_equal %w[email first_name id last_name role], user.keys.sort
  end

  test "me requires authentication" do
    get me_url

    assert_response :unauthorized
  end

  test "a token from login works on me" do
    post login_url, params: { email: "carmen@example.com", password: "password123" }, as: :json
    token = response.parsed_body["token"]

    get me_url, headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
    assert_equal "carmen@example.com", response.parsed_body["user"]["email"]
  end

  test "health check stays public" do
    get rails_health_check_url

    assert_response :success
  end
end
