class ApplicationController < ActionController::Base
  layout :application_layout

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :ensure_plan_selected
  before_action :record_daily_visit

  protected

  def record_daily_visit
    return unless user_signed_in? && request.get? && request.path.start_with?("/app/")
    DailyVisit.record_for(current_user)
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => error
    @daily_visit_unavailable = true
    Rails.logger.warn("Daily access recording unavailable (#{error.class})")
  end

  def application_layout
    return "application" unless devise_controller?

    user_signed_in? ? "platform" : "authentication"
  end

  def configure_permitted_parameters
    extra_attrs = [
      :full_name,
      :phone,
      :plan
    ]

    devise_parameter_sanitizer.permit(:sign_up, keys: extra_attrs)
    devise_parameter_sanitizer.permit(:account_update, keys: extra_attrs)
  end

  def ensure_plan_selected
    return unless user_signed_in?
    return if current_user.plan.present?
    return if devise_controller?
    return if controller_name == "onboarding"

    redirect_to onboarding_plan_path
  end
end
