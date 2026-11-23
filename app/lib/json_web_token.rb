# Thin wrapper around the jwt gem. Tokens are signed with the application's
# secret_key_base and always carry an expiry.
class JsonWebToken
  ALGORITHM = "HS256".freeze
  DEFAULT_EXPIRATION = 24.hours

  class << self
    # JsonWebToken.encode(sub: user.id.to_s, expires_in: 1.hour)
    def encode(expires_in: DEFAULT_EXPIRATION, **claims)
      JWT.encode(claims.merge(exp: expires_in.from_now.to_i), secret, ALGORITHM)
    end

    # Returns the payload as a HashWithIndifferentAccess.
    # Raises JWT::DecodeError (or a subclass such as JWT::ExpiredSignature)
    # when the token is malformed, tampered with or expired.
    def decode(token)
      payload, _header = JWT.decode(token, secret, true, algorithm: ALGORITHM)
      payload.with_indifferent_access
    end

    private

    def secret
      Rails.application.secret_key_base
    end
  end
end
