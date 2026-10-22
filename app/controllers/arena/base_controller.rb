module Arena
  class BaseController < ApplicationController
    skip_before_action :ensure_plan_selected
    before_action :authenticate_user!
    before_action :private_response
    layout "platform"

    rescue_from Forbidden, ActiveRecord::RecordNotFound do
      render_arena_error("Sala indisponível para esta conta.", :not_found)
    end
    rescue_from Conflict do |error|
      render_arena_error(error.message, :conflict)
    end
    rescue_from RateLimited do |error|
      response.set_header("Retry-After", "60")
      render_arena_error(error.message, :too_many_requests)
    end
    rescue_from Unavailable do |error|
      render_arena_error(error.message, :unprocessable_entity)
    end
    rescue_from InvalidContent, InvalidAnswer, AlreadyAnswered, InvalidTransition, ActiveRecord::RecordInvalid do
      render_arena_error("Não foi possível concluir a ação. Atualize a sala e tente novamente.", :unprocessable_entity)
    end

    private

    def private_response
      response.set_header("Cache-Control", "private, no-store, max-age=0")
      response.set_header("Referrer-Policy", "same-origin")
    end

    def render_arena_error(message, status)
      respond_to do |format|
        format.json { render json: { error: message }, status: status }
        format.html { @arena_error = message; render "arena/sessions/error", status: status }
        format.csv { render plain: message, status: status, content_type: "text/plain" }
      end
    end
  end
end
