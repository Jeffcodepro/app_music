module Arena
  class Directory
    # Authenticated controller only. A summary never authorizes admission.
    def self.rows
      SchemaIntegrity.verify!
      ArenaSession.where(visibility: "public", state: "lobby_open").where("invite_expires_at > ?", DatabaseClock.now)
        .where("arena_sessions.experience <> 'party' OR EXISTS (SELECT 1 FROM arena_memberships host_member WHERE host_member.arena_session_id=arena_sessions.id AND host_member.user_id=arena_sessions.host_id AND host_member.status='active')")
        .left_joins(:arena_memberships).joins(:arena_content_version)
        .select("arena_sessions.*, count(arena_memberships.id) FILTER (WHERE arena_memberships.status='active') AS active_count")
        .group("arena_sessions.id").having("count(arena_memberships.id) FILTER (WHERE arena_memberships.status='active') < arena_sessions.capacity")
        .order(created_at: :desc).limit(20).preload(:arena_content_version).map do |room|
          { id: room.id, title: room.title, content: room.arena_content_version.title,
            participants: room[:active_count].to_i, capacity: room.capacity, duration_seconds: room.duration_seconds }
        end
    end
  end
end
