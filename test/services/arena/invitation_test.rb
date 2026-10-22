require "test_helper"
require_relative "../../support/arena_foundation_helpers"

class ArenaInvitationTest < ActiveSupport::TestCase
  include ArenaFoundationHelpers

  test "typed codes and invitation links normalize without trusting a redirect destination" do
    code = "ABCD1234EFGH5678"
    ["abcd 1234-efgh 5678", "ABCD\u00a01234\u2009EFGH\u00a05678", "http://127.0.0.1:3001/app/arena?code=#{code}"].each do |input|
      assert_equal code, Arena::Invites.normalize(input)
      assert_equal Arena::Invites.digest(code), Arena::Invites.digest(input)
    end
    ["short", "A" * 2049, "javascript:alert(1)", "http://example.test/users?code=#{code}", "http://example.test/app/arena?code=#{code}&code=#{code}"].each do |input|
      assert_nil Arena::Invites.normalize(input)
    end
  end

  test "an account without a teacher grant can host and its deletion still anonymizes the session" do
    user = arena_user
    refute ArenaHostGrant.exists?(user: user)
    session = arena_session(user)
    user.destroy!
    assert_nil session.reload.host_id
    assert_equal "cancelled", session.state
    assert_equal "Sessão encerrada", session.title
  end

  test "renewal preserves admitted members and cannot reopen a started session" do
    host, student = arena_user, arena_user
    content = Arena::Catalog.create_preview!
    session = Arena::Game.create!(actor: host, content_version: content, title: "Convites", question_count: 1, duration_seconds: 30, technical_preview: true)
    old_code = Arena::Invites.code(session)
    member = Arena::Join.call(actor: student, code: old_code, nickname: "Aluno")
    Arena::Game.command!(actor: host, session: session, command: "renew_invite", expected_version: session.reload.lock_version)
    refute_equal old_code, Arena::Invites.code(session.reload)
    assert_equal "active", member.reload.status
    assert_equal member.id, Arena::Join.call(actor: student, code: Arena::Invites.code(session), nickname: "Aluno").id
    Arena::Game.command!(actor: host, session: session, command: "start", expected_version: session.lock_version)
    assert_raises(Arena::InvalidTransition) do
      Arena::Game.command!(actor: host, session: session, command: "renew_invite", expected_version: session.lock_version)
    end
    assert_equal "live", session.reload.state
  end
end
