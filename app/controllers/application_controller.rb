class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :ensure_plan_selected

  protected

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
