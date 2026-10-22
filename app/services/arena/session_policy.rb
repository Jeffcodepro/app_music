module Arena
  class SessionPolicy
    def initialize(actor, session = nil)
      @actor, @session = actor, session
    end

    def create? = @actor&.persisted?
    def control? = create? && @session&.host_id == @actor.id
    def participate? = @actor&.persisted? && @session && ArenaMembership.exists?(arena_session_id: @session.id, user_id: @actor.id, status: "active")
    def departed? = @actor&.persisted? && @session && ArenaMembership.exists?(arena_session_id: @session.id, user_id: @actor.id, status: "left")
    def view? = control? || participate? || departed?
  end
end
