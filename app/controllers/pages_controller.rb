class PagesController < ApplicationController
  def home
    return unless user_signed_in?

    redirect_to app_dashboard_path
  end
end
