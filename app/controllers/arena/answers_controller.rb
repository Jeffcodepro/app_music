module Arena
  class AnswersController < BaseController
    def create
      RateLimit.consume!(scope: "answer", subject: current_user.id, limit: 60)
      round = ArenaRound.find(params[:id])
      ack = RecordAnswer.call(actor: current_user, round: round, option_id: params[:option_id].to_s, idempotency_key: params[:idempotency_key].to_s)
      respond_to do |format|
        format.json { render json: ack }
        format.html { redirect_to app_arena_session_path(round.arena_session_id), notice: "Resposta recebida.", status: :see_other }
      end
    end
  end
end
