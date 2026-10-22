require "test_helper"
require "minitest/mock"
require_relative "../../support/arena_foundation_helpers"

class ArenaPartyFlowTest < ActionDispatch::IntegrationTest
  include ArenaFoundationHelpers

  test "creator answers on the same screen and members see the final podium only inside their game" do
    host, student, outsider = arena_user, arena_user, arena_user
    content = Arena::Catalog.create_preview!
    Arena::Catalog.publish!(content: content, reviewer_reference: SecureRandom.uuid)
    creator, guest, foreign = open_session, open_session, open_session
    [[creator,host],[guest,student],[foreign,outsider]].each do |client,user|
      client.post user_session_path, params: { user: { email: user.email, password: "isolated-arena-password" } }
    end
    creator.post app_arena_sessions_path, params: { host_avatar: "owl", host_nickname: "Maestro", title: "Jogo", content_version_id: content.id, question_count: 1, duration_seconds: 30 }
    assert_equal 303, creator.response.status
    room = ArenaSession.find_by!(host: host)
    assert_equal "party", room.experience
    guest.post join_app_arena_path, params: { avatar_id: "cat", code: Arena::Invites.code(room), nickname: "Sabiá" }
    creator.post command_app_arena_session_path(room), params: { command: "start", version: room.reload.lock_version }
    creator.get app_arena_session_path(room)
    assert_equal 200, creator.response.status
    assert_includes creator.response.body, "Valendo em…"
    refute Nokogiri::HTML(creator.response.body).at_css('.arena-score')
    round = room.arena_rounds.sole
    clock = round.answer_open_at
    Arena::DatabaseClock.stub(:now,clock) do
      guest.post settle_app_arena_session_path(room)
      creator.get app_arena_session_path(room)
      assert_equal 200, creator.response.status
      assert Nokogiri::HTML(creator.response.body).at_css("form[action='#{answer_app_arena_round_path(round)}']")
      refute_includes creator.response.body, "correct_option_id"
      option = round.arena_question_snapshot.payload.fetch("correct_option_id")
      [creator,guest].each do |client|
        client.post answer_app_arena_round_path(round), params: { option_id: option, idempotency_key: SecureRandom.uuid, points: 999999, correct: true }, as: :json
        assert_equal 200, client.response.status
        refute_match(/points|correct/, client.response.body)
      end
      guest.post settle_app_arena_session_path(room)
    end
    clock = round.reload.advance_at
    Arena::DatabaseClock.stub(:now,clock) { guest.post settle_app_arena_session_path(room) }
    guest.get app_arena_session_path(room)
    assert_equal 200, guest.response.status
    assert Nokogiri::HTML(guest.response.body).at_css('.arena-podium')
    assert_includes guest.response.body, "Maestro"
    assert_includes guest.response.body, "Sabiá"
    game_html = Nokogiri::HTML(guest.response.body).at_css("section.arena").to_html
    [host,student].each { |user| refute_includes game_html, user.email }
    foreign.get app_arena_session_path(room, format: :json)
    assert_equal 404, foreign.response.status
    guest.post rematch_app_arena_session_path(room), params: { version: room.reload.lock_version }
    assert_equal 404, guest.response.status
    creator.post rematch_app_arena_session_path(room), params: { version: room.reload.lock_version }
    assert_equal 303, creator.response.status
    assert room.reload.rematch_session_id
    guest.get app_arena_session_path(room)
    assert_includes guest.response.body, "Entrar na revanche"
  end
end
