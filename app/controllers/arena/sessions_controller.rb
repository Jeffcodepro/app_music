module Arena
  class SessionsController < BaseController
    def index
      if (own_room = Invites.owned_session(actor: current_user, code: params[:code]))
        return redirect_to app_arena_session_path(own_room), status: :see_other
      end
      return prepare if params[:code].present? || params[:public_session_id].present?
      load_entry
    end

    def create
      raise Forbidden unless SessionPolicy.new(current_user).create?
      RateLimit.consume!(scope: "create", subject: current_user.id, limit: 10)
      content = if params[:music_area].present?
        profile = MusicContent.profile!(area: params[:music_area], level: params[:music_level], kind: params.fetch(:music_kind,"mixed"))
        if Catalog.technical_preview?
          MusicContent.create_preview!(**profile.symbolize_keys)
        else
          Catalog.available.find { |version| version.body["type"] == MusicContent::TYPE && version.body["profile"] == profile } || raise(InvalidContent)
        end
      else
        Catalog.available.find(params[:content_version_id])
      end
      host_mode = params.fetch(:host_mode,"play").to_s
      raise InvalidContent unless %w[play present].include?(host_mode)
      room = Game.create!(actor: current_user, content_version: content, title: params[:title].to_s,
        question_count: params[:question_count], duration_seconds: params[:duration_seconds],
        listening_repetitions: params.fetch(:listening_repetitions, 3), technical_preview: Catalog.technical_preview?,
        experience: params[:prepare_lobby] == "1" ? (host_mode == "present" ? "facilitated" : "party") : params.fetch(:experience, "party").to_s, host_nickname: params[:host_nickname], host_avatar: params[:host_avatar],
        visibility: params.fetch(:visibility, "private").to_s, capacity: params.fetch(:capacity, 40), scoring_version: Scoring::CURRENT,
        defer_host_identity: params[:prepare_lobby] == "1", presentation_mode: params[:prepare_lobby] == "1" ? (host_mode == "present" ? "presenter" : "individual") : "legacy")
      redirect_to app_arena_session_path(room), status: :see_other
    rescue Unavailable, InvalidContent, ActiveRecord::RecordInvalid => error
      @arena_create_error = error.is_a?(Unavailable) ? error.message : "Confira o nome e a configuração da sala."
      load_entry
      render :index, status: :unprocessable_entity
    end

    def join
      RateLimit.consume!(scope: "join-account", subject: current_user.id, limit: 10)
      RateLimit.consume!(scope: "join-network", subject: request.remote_ip, limit: 120)
      if (own_room = Invites.owned_session(actor: current_user, code: params[:code]))
        return redirect_to app_arena_session_path(own_room), status: :see_other
      end
      member = Join.call(actor: current_user, code: params[:code], public_session_id: params[:public_session_id], nickname: params[:nickname], avatar_id: params[:avatar_id])
      respond_to do |format|
        format.html { redirect_to app_arena_session_path(member.arena_session_id), status: :see_other }
        format.json { render json: { location: app_arena_session_path(member.arena_session_id) }, status: :created }
      end
    rescue Unavailable => error
      respond_to do |format|
        format.json { render json: { error: error.message }, status: :unprocessable_entity }
        format.html do
          @arena_entry_error = error.message
          load_entry
          render :index, status: :unprocessable_entity
        end
      end
    end

    def show
      @room = ArenaSession.find(params[:id])
      policy = SessionPolicy.new(current_user, @room)
      if !policy.control? && AudioCheck.excluded?(@room,current_user) && request.format.html? && params[:fragment] != "1"
        return redirect_to app_arena_path(audio: "expired"), status: :see_other
      end
      @state = if !policy.control? && AudioCheck.excluded?(@room,current_user)
        AudioCheck.exclusion_view(@room, actor: current_user)
      elsif policy.view?
        SessionView.call(actor: current_user, session: @room)
      else
        LobbyAccess.view!(actor: current_user, session: @room, grant: lobby_grant(@room))
      end
      respond_to do |format|
        format.json { render json: @state }
        format.html do
          if @state[:identity_required]
            load_identity
            render :lobby
          elsif params[:fragment] == "1"
            response.set_header("X-Arena-Sequence", @state[:sequence].to_s)
            render partial: "arena/sessions/session", locals: { state: @state }
          end
        end
      end
    end

    def prepare
      RateLimit.consume!(scope: "join-account", subject: current_user.id, limit: 10)
      RateLimit.consume!(scope: "join-network", subject: request.remote_ip, limit: 120)
      room, grant = LobbyAccess.prepare!(actor: current_user, code: params[:code], public_session_id: params[:public_session_id])
      if grant
        permissions = (session[:arena_lobby_admissions] || {}).to_h.reject { |_id,value| value["user_id"] != current_user.id || value["expires_at"].to_i <= DatabaseClock.now.to_i }
        permissions.shift while permissions.size >= 5
        permissions[room.id] = grant
        session[:arena_lobby_admissions] = permissions
      end
      redirect_to app_arena_session_path(room), status: :see_other
    rescue Unavailable => error
      @arena_entry_error = error.message
      load_entry
      render :index, status: :unprocessable_entity
    end

    def ready
      RateLimit.consume!(scope: "join-account", subject: current_user.id, limit: 10)
      @room = ArenaSession.find(params[:id])
      LobbyAccess.confirm!(actor: current_user, session: @room, grant: lobby_grant(@room), nickname: params[:nickname], avatar_id: params[:avatar_id])
      redirect_to app_arena_session_path(@room), status: :see_other
    rescue Unavailable, ActiveRecord::RecordInvalid => error
      @state = LobbyAccess.view!(actor: current_user, session: @room, grant: lobby_grant(@room))
      @arena_identity_error = error.is_a?(Unavailable) ? error.message : "Confira seu personagem e apelido."
      load_identity
      render :lobby, status: :unprocessable_entity
    end

    def command
      room = ArenaSession.find(params[:id])
      RateLimit.consume!(scope: "command", subject: current_user.id, limit: 120)
      Game.command!(actor: current_user, session: room, command: params[:command].to_s,
        expected_version: Integer(params[:version].to_s, exception: false))
      respond_to do |format|
        format.json { head :no_content }
        format.html { redirect_to params[:return_to] == "arena" ? app_arena_path : app_arena_session_path(room), status: :see_other }
      end
    end

    def audio_ready
      RateLimit.consume!(scope: "audio-ready", subject: current_user.id, limit: 90)
      room = ArenaSession.find(params[:id])
      raise InvalidTransition unless [true, false].include?(params[:ready])
      AudioCheck.confirm!(actor: current_user, session: room, check_id: params[:check_id], ready: params[:ready])
      Game.settle!(actor: current_user, session: room)
      head :no_content
    end

    def settle
      room = ArenaSession.find(params[:id])
      Game.settle!(actor: current_user, session: room)
      head :no_content
    end

    def rematch
      RateLimit.consume!(scope: "create", subject: current_user.id, limit: 10)
      room = Game.rematch!(actor: current_user, session: ArenaSession.find(params[:id]), expected_version: Integer(params[:version].to_s, exception: false))
      redirect_to app_arena_session_path(room), status: :see_other
    end

    def remove_member
      RateLimit.consume!(scope: "command", subject: current_user.id, limit: 120)
      room = ArenaSession.find(params[:id])
      Lobby.remove!(actor: current_user, session: room, membership_id: params[:membership_id], expected_version: Integer(params[:version].to_s, exception: false))
      redirect_to app_arena_session_path(room), status: :see_other
    end

    def leave
      RateLimit.consume!(scope: "command", subject: current_user.id, limit: 120)
      Lobby.leave!(actor: current_user, session: ArenaSession.find(params[:id]))
      redirect_to app_arena_path, status: :see_other, notice: "Você saiu da sala. Seus pontos foram preservados."
    end

    def report
      @room = ArenaSession.find(params[:id])
      @report = Report.call(actor: current_user, session: @room)
      respond_to do |format|
        format.html
        format.csv { send_data "\uFEFF#{Report.csv(@report)}", type: "text/csv; charset=utf-8", filename: "arena-resultados.csv", disposition: "attachment" }
      end
    end

    private

    def lobby_grant(room)
      session[:arena_lobby_admissions]&.dig(room.id)
    end

    def load_identity
      @avatar_id = Avatars::CHOICES.key?(params[:avatar_id]) ? params[:avatar_id] : nil
      @nickname = params[:nickname].to_s.first(32)
    end

    def load_entry
      @can_host = SessionPolicy.new(current_user).create?
      @catalog = Catalog.available
      @public_rooms = Directory.rows
      @public_room = @public_rooms.find { |room| room[:id] == params[:public_session_id] }
      @avatar_id = Avatars::CHOICES.key?(params[:avatar_id]) ? params[:avatar_id] : nil
      @host_avatar = Avatars::CHOICES.key?(params[:host_avatar]) ? params[:host_avatar] : nil
      @active_host_sessions = ArenaSession.where(host: current_user).where.not(state: ArenaSession::TERMINAL).order(created_at: :desc)
      own = ArenaSession.where(host: current_user).select(:id)
      joined = ArenaMembership.where(user: current_user, status: %w[active left]).select(:arena_session_id)
      @recent_sessions = ArenaSession.where(id: own).or(ArenaSession.where(id: joined)).order(created_at: :desc).limit(6)
      @invitation_code = Invites.normalize(params[:code]) || params[:code].to_s.first(2048)
      @nickname = params[:nickname].to_s.first(32)
    end
  end
end
