require "test_helper"
require "minitest/mock"
require_relative "../../support/arena_foundation_helpers"

class ArenaContentContractTest < ActiveSupport::TestCase
  include ArenaFoundationHelpers
  setup { @content = Arena::Catalog.create_preview! }

  test "natural note adapter rejects accidentals key signatures and markup" do
    exercise = @content.body.fetch("exercises").first
    [{ "key_signature_accidentals" => [{ "symbol" => "</text><script>alert(1)</script>", "staff_position_index" => 0 }] },
      { "key_signature_id" => "g_major" }, { "note_accidental_symbol" => "♯" }].each do |extra|
      assert_raises(Arena::InvalidContent) { Arena::ReadingContent.validate!(exercise.merge(extra)) }
    end
  end

  test "snapshot source is exact and frozen SVG survives a later renderer change" do
    host = arena_user
    arena_grant(host)
    room = Arena::Game.create!(actor: host, content_version: @content, title: "Source", question_count: 1, duration_seconds: 30, technical_preview: true)
    snapshot = room.arena_question_snapshots.sole
    original_svg = snapshot.payload.fetch("svg")
    Arena::ReadingContent.stub(:render, "future renderer") do
      assert_equal original_svg, Arena::Projections.question(snapshot).fetch(:svg)
    end
    corrupt = snapshot.payload.deep_dup
    corrupt["svg"] += "<script>alert(1)</script>"
    snapshot.payload["svg"] = corrupt.fetch("svg")
    assert_raises(Arena::InvalidContent) { Arena::Projections.question(snapshot) }

    changed = @content.body.fetch("exercises").first.deep_dup
    changed["options"] = changed.fetch("options").reverse
    payload = Arena::ReadingContent.snapshot(changed, content_version: @content)
    assert_raises(ActiveRecord::RecordInvalid) do
      ArenaQuestionSnapshot.create!(arena_session: room, arena_content_version: @content, payload_version: "reading-note-v1", payload: payload)
    end
  end

  test "archived content rejects stale creation and review history cannot be rewritten" do
    Arena::Catalog.publish!(content: @content, reviewer_reference: SecureRandom.uuid)
    stale = ArenaContentVersion.find(@content.id)
    @content.update!(status: "archived")
    host = arena_user
    arena_grant(host)
    assert_raises(Arena::InvalidContent) do
      Arena::Game.create!(actor: host, content_version: stale, title: "Stale", question_count: 1, duration_seconds: 30)
    end
    assert_equal 0, ArenaSession.where(host: host).count
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaContentVersion.transaction(requires_new: true) do
        ArenaContentVersion.where(id: @content.id).update_all(reviewer_reference: nil, reviewed_at: nil)
      end
    end
  end

  test "database rejects partial pilot configuration and preserves F1 null configuration" do
    host = arena_user
    arena_grant(host)
    legacy = arena_session(host)
    assert_nil legacy.arena_content_version_id
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaSession.transaction(requires_new: true) { ArenaSession.where(id: legacy.id).update_all(arena_content_version_id: @content.id) }
    end
  end
end
