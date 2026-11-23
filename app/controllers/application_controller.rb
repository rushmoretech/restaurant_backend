class ApplicationController < ActionController::API
  include Authenticatable

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "Not found" }, status: :not_found
  end

  private

  def render_errors(record)
    render json: { errors: record.errors.full_messages }, status: :unprocessable_content
  end
end
