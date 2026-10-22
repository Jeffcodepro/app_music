require "test_helper"
require "minitest/mock"
require_relative "../../support/arena_foundation_helpers"

class ArenaAudioCheckTest < ActiveSupport::TestCase
  include ArenaFoundationHelpers
  def build_room(area: "percepcao", experience: "party", legacy: false)
    @host, @student = arena_user, arena_user
    content = Arena::MusicContent.create_preview!(area: area, level: "1", kind: area == "percepcao" ? "interval" : "mixed")
    @room = Arena::Game.create!(actor: @host, content_version: content, title: "Passagem de som", question_count: 2, duration_seconds: 10,
      technical_preview: true, experience: experience, listening_repetitions: legacy ? nil : 1)
    @student_member = Arena::Join.call(actor: @student, code: Arena::Invites.code(@room), nickname: "Sol")
    @now = Time.current
    at(@now) { command("start") }
  end
  def at(time, &block) = Arena::DatabaseClock.stub(:now, time, &block)
  def command(name) = Arena::Game.command!(actor: @host, session: @room, command: name, expected_version: @room.reload.lock_version)
  def confirm(actor, time: @now, ready: true)
    at(time) { Arena::AudioCheck.confirm!(actor: actor, session: @room, check_id: @room.reload.audio_check_id, ready: ready) }
  end
  def settle(time)
    at(time) { Arena::Game.settle!(actor: @host, session: @room) }
  end

  test "preparation owns exactly forty five seconds and opens no exercise before readiness" do
    build_room
    assert_equal "lobby_locked", @room.reload.state
    assert_in_delta @now + 45, @room.audio_check_deadline_at, 0.00001
    assert_equal ["queued"], @room.arena_rounds.distinct.pluck(:state)
    view = Arena::SessionView.call(actor: @student, session: @room)
    assert_equal "audio_check", view[:phase]
    assert_nil view[:round]
    assert_equal 2, view[:audio_check][:required_count]
    refute view[:audio_check].key?(:audio_ready_at)
    old_id = @room.audio_check_id
    at(@now + 20) { command("start") }
    assert_equal old_id, @room.reload.audio_check_id
    assert_in_delta @now + 45, @room.audio_check_deadline_at, 0.00001
  end

  test "all ready starts early once and later rounds never repeat preparation" do
    build_room
    confirm(@host, time: @now + 2)
    settle(@now + 2)
    assert_equal "lobby_locked", @room.reload.state
    confirm(@student, time: @now + 7)
    settle(@now + 7)
    assert_equal "live", @room.reload.state
    first = @room.arena_rounds.order(:position).first
    assert_equal "ready", first.state
    assert_in_delta @now + 7, first.listening_started_at, 0.00001
    sequence = @room.event_sequence
    settle(@now + 7)
    assert_equal sequence, @room.reload.event_sequence
    at(@now + 8) { command("void"); command("next") }
    assert_equal "live", @room.reload.state
    second = @room.arena_rounds.order(:position).last
    assert_equal "ready", second.state
    assert_in_delta @now + 8 + Arena::Playback::WARMUP_SECONDS + 2, Arena::Playback.cue_at(second,1) + 2, 0.00001
  end

  test "deadline removes only unready members and their own projection is limited" do
    build_room
    confirm(@host)
    settle(@now + 44.999)
    assert_equal "active", @student_member.reload.status
    assert_equal "lobby_locked", @room.reload.state
    settle(@now + 45)
    assert_equal "live", @room.reload.state
    assert_equal "removed", @student_member.reload.status
    assert @student_member.audio_excluded_at
    view = Arena::SessionView.call(actor: @student, session: @room)
    assert_equal "audio_excluded", view[:phase]
    [:round,:roster,:ranking,:share,:invite].each { |private_key| refute view.key?(private_key) }
    assert_empty @room.arena_answers
    assert_raises(Arena::Forbidden) { Arena::AudioCheck.confirm!(actor: @student, session: @room, check_id: @room.audio_check_id) }
  end

  test "host who misses readiness stays owner while ready players continue" do
    build_room
    confirm(@student)
    settle(@now + 45)
    assert_equal "live", @room.reload.state
    assert_equal "removed", @room.arena_memberships.find_by!(user: @host).status
    assert Arena::SessionPolicy.new(@host,@room).control?
    view = Arena::SessionView.call(actor: @host, session: @room)
    assert view[:host_audio_excluded]
    refute view[:participant]
    assert_equal 1, view[:participant_count]
    command("pause")
    assert_equal "paused", @room.reload.state
  end

  test "no ready players cancels without round result or podium" do
    build_room
    settle(@now + 45)
    assert_equal "cancelled", @room.reload.state
    assert_equal 0, @room.arena_memberships.where(status: "active").count
    assert_equal 0, @room.arena_rounds.where.not(state: "queued").count
    assert_empty @room.arena_answers
    assert_nil Arena::SessionView.call(actor: @host, session: @room)[:podium]
  end

  test "presenter requires only its own device and failure does not expel the class" do
    build_room(experience: "facilitated")
    assert_raises(Arena::Forbidden) { confirm(@student) }
    assert_equal 1, Arena::SessionView.call(actor: @host, session: @room)[:audio_check][:required_count]
    refute Arena::SessionView.call(actor: @student, session: @room)[:audio_check][:needs_activation]
    confirm(@host, time: @now + 4)
    settle(@now + 4)
    assert_equal "live", @room.reload.state
    command("end")
    build_room(experience: "facilitated")
    settle(@now + 45)
    assert_equal "cancelled", @room.reload.state
    assert_equal "active", @student_member.reload.status
  end

  test "visual matches and legacy listening skip audio preparation" do
    build_room(area: "leitura")
    assert_equal "live", @room.reload.state
    assert_nil @room.audio_check_id
    refute Arena::SessionView.call(actor: @host, session: @room)[:audio_required]
    command("end")
    build_room(legacy: true)
    assert_equal "live", @room.reload.state
    assert_nil @room.audio_check_id
  end

  test "wrong token outsider deadline and cancelled preparation cannot acknowledge readiness" do
    build_room
    assert_raises(Arena::InvalidTransition) { Arena::AudioCheck.confirm!(actor: @student, session: @room, check_id: SecureRandom.uuid) }
    assert_raises(Arena::Forbidden) { Arena::AudioCheck.confirm!(actor: arena_user, session: @room, check_id: @room.audio_check_id) }
    assert_raises(Arena::InvalidTransition) { confirm(@student, time: @now + 45) }
    assert_nil @student_member.reload.audio_ready_at
    command("end")
    assert_raises(Arena::InvalidTransition) { confirm(@student) }
  end

  test "duplicate ack is idempotent reload can revoke its own ack and departure changes readiness" do
    build_room
    confirm(@host)
    sequence = @room.reload.event_sequence
    confirm(@host, time: @now + 1)
    assert_equal sequence, @room.reload.event_sequence
    confirm(@host, time: @now + 2, ready: false)
    refute Arena::AudioCheck.ready?(@room.reload)
    confirm(@host, time: @now + 3)
    Arena::Lobby.leave!(actor: @student, session: @room)
    settle(@now + 4)
    assert_equal "live", @room.reload.state
  end

  test "native guards cannot extend the clock or forge a readiness time outside it" do
    build_room
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaSession.transaction(requires_new: true) { ArenaSession.where(id: @room.id).update_all(audio_check_deadline_at: @now + 90) }
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaMembership.transaction(requires_new: true) { @student_member.update_columns(audio_ready_at: @now + 45) }
    end
  end
  test "a participant who leaves cannot recover other players preparation identities" do
    build_room
    Arena::Lobby.leave!(actor: @student, session: @room)
    view = Arena::SessionView.call(actor: @student, session: @room)
    assert_equal "departed", view[:phase]
    assert_nil view[:audio_check]
    assert_nil view[:roster]
    assert_nil view[:round]
    refute_includes view.to_json, @room.audio_check_id
    assert Arena::SessionView.call(actor: @host, session: @room)[:audio_check]
  end

end
