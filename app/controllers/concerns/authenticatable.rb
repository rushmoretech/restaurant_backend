# Token authentication and role-based authorization for API controllers.
#
# Every action requires a valid `Authorization: Bearer <jwt>` header by
# default. Public endpoints opt out with:
#
#   skip_before_action :authenticate_request!
#
# Restrict an action to some roles with:
#
#   before_action -> { authorize_roles!(:chef, :admin) }, only: :update
module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request!
  end

  private

  attr_reader :current_user

  def authenticate_request!
    token = bearer_token
    return render_unauthorized("Missing authentication token") if token.blank?

    payload = JsonWebToken.decode(token)
    @current_user = User.find(payload[:sub])
  rescue JWT::DecodeError, ActiveRecord::RecordNotFound
    render_unauthorized("Invalid or expired authentication token")
  end

  def authorize_roles!(*roles)
    return if roles.map(&:to_s).include?(current_user.role)

    render json: { error: "You are not allowed to perform this action" }, status: :forbidden
  end

  def bearer_token
    request.authorization.to_s[/\ABearer\s+(\S+)\z/i, 1]
  end

  def render_unauthorized(message)
    response.headers["WWW-Authenticate"] = "Bearer"
    render json: { error: message }, status: :unauthorized
  end
end
