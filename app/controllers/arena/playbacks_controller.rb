module Arena
  class PlaybacksController < BaseController
    def create
      RateLimit.consume!(scope: "playback", subject: current_user.id, limit: 180)
      render json: Playback.start!(actor: current_user, round: ArenaRound.find(params[:id]), generation: Integer(params[:generation].to_s, exception: false), listen: Integer(params[:listen].to_s, exception: false))
    end
    def complete
      Playback.complete!(actor: current_user, round: ArenaRound.find(params[:id]), token: params[:token], generation: Integer(params[:generation].to_s, exception: false), listen: Integer(params[:listen].to_s, exception: false))
      head :no_content
    end
  end
end
