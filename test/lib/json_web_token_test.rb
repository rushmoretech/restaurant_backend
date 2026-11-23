require "test_helper"

class JsonWebTokenTest < ActiveSupport::TestCase
  test "encodes and decodes a payload" do
    token = JsonWebToken.encode(sub: "42")
    assert_equal "42", JsonWebToken.decode(token)[:sub]
  end

  test "tokens carry an expiry" do
    payload = JsonWebToken.decode(JsonWebToken.encode(sub: "1", expires_in: 1.hour))
    assert_in_delta 1.hour.from_now.to_i, payload[:exp], 5
  end

  test "rejects an expired token" do
    token = JsonWebToken.encode(sub: "1", expires_in: -1.minute)
    assert_raises(JWT::ExpiredSignature) { JsonWebToken.decode(token) }
  end

  test "rejects a token signed with another secret" do
    forged = JWT.encode({ sub: "1", exp: 1.hour.from_now.to_i }, "other-secret", "HS256")
    assert_raises(JWT::VerificationError) { JsonWebToken.decode(forged) }
  end

  test "rejects an unsigned token" do
    unsigned = JWT.encode({ sub: "1", exp: 1.hour.from_now.to_i }, nil, "none")
    assert_raises(JWT::DecodeError) { JsonWebToken.decode(unsigned) }
  end

  test "rejects garbage" do
    assert_raises(JWT::DecodeError) { JsonWebToken.decode("not.a.token") }
  end
end
