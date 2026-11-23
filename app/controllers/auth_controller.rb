class AuthController < ApplicationController
  skip_before_action :authenticate_request!, only: %i[signup login]

  rate_limit to: 10, within: 3.minutes, only: %i[signup login],
             with: -> { render json: { error: "Too many attempts, try again later" }, status: :too_many_requests }

  # POST /signup — public registration. Always creates a customer: the role
  # is never read from the request, so staff accounts must be created by an admin.
  def signup
    user = User.new(signup_params)

    if user.save
      render json: auth_payload(user), status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_content
    end
  end

  # POST /login
  def login
    user = User.find_by(email: params[:email].to_s)

    if user&.authenticate(params[:password].to_s)
      render json: auth_payload(user)
    else
      render_unauthorized("Invalid email or password")
    end
  end

  # GET /me
  def me
    render json: { user: user_json(current_user) }
  end

  private

  def signup_params
    params.permit(:first_name, :last_name, :email, :password, :password_confirmation)
  end

  def auth_payload(user)
    { token: JsonWebToken.encode(sub: user.id.to_s), user: user_json(user) }
  end

  def user_json(user)
    user.slice(:id, :first_name, :last_name, :email, :role)
  end
end
