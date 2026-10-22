require "test_helper"
require "minitest/mock"
require_relative "../../support/arena_foundation_helpers"

class ArenaEncoreTest < ActiveSupport::TestCase
  include ArenaFoundationHelpers

  test "new game supports fifty questions and forty players with database admission protection" do
    host = arena_user
    content = Arena::MusicContent.create_preview!(area: "leitura", level: "1")
    room = Arena::Game.create!(actor: host, content_version: content, title: "Turma", question_count: 50,
      duration_seconds: 10, capacity: 40, experience: "facilitated", technical_preview: true, presentation_mode: "presenter")
    assert_equal 50, room.arena_rounds.count
    assert_equal "presenter", room.presentation_mode
    assert_empty room.arena_memberships
    40.times { |i| ArenaMembership.create!(arena_session: room, user: arena_user, nickname: "Pessoa #{i}", avatar_id: "rabbit") }
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaMembership.transaction(requires_new: true) { ArenaMembership.create!(arena_session: room, user: arena_user, nickname: "Extra") }
    end
    assert_equal 40, room.arena_memberships.count
    assert_raises(Arena::InvalidContent) do
      Arena::Game.create!(actor: host, content_version: content, title: "Extra", question_count: 51, duration_seconds: 10, technical_preview: true)
    end
    assert_raises(Arena::InvalidContent) do
      Arena::Game.create!(actor: host, content_version: content, title: "Extra", question_count: 1, duration_seconds: 10, capacity: 41, technical_preview: true)
    end
  end

  test "presenter audio finishes before the shared answer clock and stale callbacks cannot resume playback" do
    host, student = arena_user, arena_user
    content = Arena::MusicContent.create_preview!(area: "percepcao", level: "1", kind: "interval")
    room = Arena::Game.create!(actor: host, content_version: content, title: "Escuta", question_count: 1,
      duration_seconds: 10, technical_preview: true, presentation_mode: "presenter")
    Arena::Join.call(actor: student, code: Arena::Invites.code(room), nickname: "Ouvido")
    now = Time.current
    Arena::DatabaseClock.stub(:now, now) { Arena::Game.command!(actor: host, session: room, command: "start", expected_version: room.reload.lock_version) }
    round = room.arena_rounds.sole
    assert_equal "ready", round.state
    assert_nil round.deadline_at
    assert_raises(Arena::Forbidden) { Arena::Playback.start!(actor: student, round: round, generation: round.playback_generation) }
    receipt = Arena::DatabaseClock.stub(:now, now) { Arena::Playback.start!(actor: host, round: round, generation: 1) }
    assert_raises(Arena::InvalidTransition) { Arena::DatabaseClock.stub(:now, now) { Arena::Playback.complete!(actor: host, round: round, token: receipt[:token], generation: 1) } }
    now += receipt[:minimum_seconds] + 0.1
    Arena::DatabaseClock.stub(:now, now) { Arena::Playback.complete!(actor: host, round: round, token: receipt[:token], generation: 1) }
    Arena::DatabaseClock.stub(:now, now) { Arena::Game.settle!(actor: student, session: room) }
    assert_in_delta now + 3, round.reload.answer_open_at, 0.01
    Arena::DatabaseClock.stub(:now,now) { Arena::Game.command!(actor: host, session: room, command: "pause", expected_version: room.reload.lock_version) }
    Arena::DatabaseClock.stub(:now,now) { Arena::Game.command!(actor: host, session: room, command: "resume", expected_version: room.reload.lock_version) }
    assert_equal 1, round.reload.playback_generation
    assert Arena::DatabaseClock.stub(:now,now) { Arena::Playback.start!(actor: host, round: round, generation: 1) }[:replay]
    Arena::DatabaseClock.stub(:now, now + 3) { Arena::Game.settle!(actor: student, session: room) }
    assert_equal "answering", round.reload.state
    assert_in_delta now + 13, round.deadline_at, 0.01
    assert_raises(Arena::InvalidTransition) { Arena::Playback.complete!(actor: host, round: round, token: receipt[:token], generation: 0) }
  end
  test "individual listening failures and pauses are neutral and departed listeners do not block the room" do
    host, student = arena_user, arena_user
    content = Arena::MusicContent.create_preview!(area: "percepcao", level: "2", kind: "melodic_dictation")
    room = Arena::Game.create!(actor: host, content_version: content, title: "Dueto", question_count: 1, duration_seconds: 10,
      technical_preview: true, experience: "party", host_avatar: "rabbit", host_nickname: "Maestro")
    Arena::Join.call(actor: student, code: Arena::Invites.code(room), nickname: "Sabiá", avatar_id: "frog")
    now = Time.current
    command = ->(name) { Arena::DatabaseClock.stub(:now,now) { Arena::Game.command!(actor: host, session: room, command: name, expected_version: room.reload.lock_version) } }
    command.call("start")
    round = room.arena_rounds.sole
    receipt = Arena::DatabaseClock.stub(:now,now) { Arena::Playback.start!(actor: host, round: round, generation: 1) }
    now += 60
    Arena::DatabaseClock.stub(:now,now) { Arena::Game.settle!(actor: host, session: room) }
    assert_nil round.reload.deadline_at
    assert_raises(Arena::InvalidAnswer) { Arena::RecordAnswer.call(actor: host, round: round, option_id: round.arena_question_snapshot.option_ids.first, idempotency_key: SecureRandom.uuid) }
    assert_equal 0, room.arena_answers.count
    command.call("pause")
    assert_equal 2, round.reload.playback_generation
    assert_empty round.playbacks
    command.call("resume")
    assert_nil round.reload.answer_open_at
    assert_raises(Arena::InvalidTransition) { Arena::Playback.complete!(actor: host, round: round, token: receipt[:token], generation: 1) }
    receipt = Arena::DatabaseClock.stub(:now,now) { Arena::Playback.start!(actor: host, round: round, generation: 2) }
    now += receipt[:minimum_seconds] + 1
    Arena::DatabaseClock.stub(:now,now) { Arena::Playback.complete!(actor: host, round: round, token: receipt[:token], generation: 2) }
    Arena::DatabaseClock.stub(:now,now) { Arena::Game.settle!(actor: host, session: room) }
    assert_nil round.reload.answer_open_at
    Arena::Lobby.leave!(actor: student, session: room)
    Arena::DatabaseClock.stub(:now,now) { Arena::Game.settle!(actor: host, session: room) }
    assert round.reload.answer_open_at
    command.call("void")
    command.call("finish")
    assert_equal "cancelled", room.reload.state
    assert_equal 0, Arena::Scoreboard.rows(room).sum { |r| r[:points] }
    assert_raises(Arena::PrivatePayload) { round.as_json }
  end

  test "share contains only the requesting player's result and no private invitation or identities" do
    host, student, outsider = arena_user, arena_user, arena_user
    room = arena_session(host)
    member = arena_membership(room,student)
    room.update!(state: "cancelled")
    shared = Arena::ScoreShare.call(actor: student, session: room)
    assert_match(/Fiz 0 pontos/, shared[:text])
    assert_equal "https://wa.me/", URI(shared[:whatsapp]).then { |u| "#{u.scheme}://#{u.host}#{u.path}" }
    assert_match(/mailto:/, shared[:email])
    [host.email,student.email,room.title,room.id,member.id].each { |private_value| refute_includes shared.to_json, private_value }
    assert_raises(Arena::Forbidden) { Arena::ScoreShare.call(actor: host, session: room) }
    assert_raises(Arena::Forbidden) { Arena::ScoreShare.call(actor: outsider, session: room) }
    member.update!(status: "left")
    assert Arena::ScoreShare.call(actor: student, session: room)
    member.update!(status: "removed")
    assert_raises(Arena::Forbidden) { Arena::ScoreShare.call(actor: student, session: room) }
  end

  test "dictation feedback reveals its frozen score only after closure and report identifies written responses" do
    host, student = arena_user, arena_user
    content = Arena::MusicContent.create_preview!(area: "percepcao", level: "1", kind: "melodic_dictation")
    room = Arena::Game.create!(actor: host, content_version: content, title: "Ditado", question_count: 1, duration_seconds: 10, technical_preview: true)
    Arena::Join.call(actor: student, code: Arena::Invites.code(room), nickname: "Sol")
    Arena::Game.command!(actor: host, session: room, command: "start", expected_version: room.reload.lock_version)
    round = room.arena_rounds.sole
    before = Arena::SessionView.call(actor: student, session: room)
    assert_nil before.dig(:round,:result)
    now = Time.current
    receipt = Arena::DatabaseClock.stub(:now,now) { Arena::Playback.start!(actor: host, round: round, generation: 1) }
    now += receipt[:minimum_seconds] + 1
    Arena::DatabaseClock.stub(:now,now) { Arena::Playback.complete!(actor: host, round: round, token: receipt[:token], generation: 1); Arena::Game.settle!(actor: host, session: room) }
    now += 3
    Arena::DatabaseClock.stub(:now,now) do
      Arena::Game.settle!(actor: host, session: room)
      Arena::RecordAnswer.call(actor: student, round: round, option_id: round.arena_question_snapshot.option_ids.first, idempotency_key: SecureRandom.uuid)
      Arena::Game.command!(actor: host, session: room, command: "finish", expected_version: room.reload.lock_version)
    end
    after = Arena::SessionView.call(actor: student, session: room)
    assert_includes after.dig(:round,:result,:correct_svg), 'class="voiced-score"'
    report = Arena::Report.call(actor: host, session: room)
    assert_match(/Voz 1:.*Dó4/, report[:questions].sole[:correct_label])
    assert_match(/Voz 1:/, report[:players].sole[:questions].sole[:selected_label])
    assert_includes report[:questions].sole[:svg], 'class="voiced-score"'
  end

end
