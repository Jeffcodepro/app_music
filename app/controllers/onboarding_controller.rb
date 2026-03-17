class OnboardingController < ApplicationController
  before_action :authenticate_user!

  def welcome
  end

  def objective
  end

  def update_objective
    objective = params[:objective].to_s
    if objective.blank?
      redirect_to onboarding_objective_path, alert: "Selecione um objetivo."
      return
    end

    session[:onboarding_objective] = objective
    redirect_to onboarding_profile_path
  end

  def profile
  end

  def update_profile
    session[:onboarding_profile] = {
      display_name: params[:display_name],
      instrument: params[:instrument],
      study_availability: params[:study_availability]
    }

    redirect_to onboarding_result_path
  end

  def result
  end

  def plan
  end

  def update_plan
    selected_plan = params[:plan].to_s
    allowed_plans = ["Primeira Nota", "Pulso", "Harmonia", "Maestro"]

    unless allowed_plans.include?(selected_plan)
      redirect_to onboarding_plan_path, alert: "Selecione um plano válido."
      return
    end

    if current_user.update(plan: selected_plan)
      redirect_to app_dashboard_path, notice: "Plano selecionado com sucesso."
    else
      redirect_to onboarding_plan_path, alert: "Não foi possível salvar seu plano."
    end
  end
end
