require "test_helper"
require "minitest/mock"
require_relative "../../support/arena_foundation_helpers"

class ArenaMusicContentTest < ActiveSupport::TestCase
  include ArenaFoundationHelpers

  test "repeated preview requests reuse and validate the existing content" do
    content = Arena::MusicContent.create_preview!(area: "percepcao", level: "1", kind: "mixed")
    assert_no_difference "ArenaContentVersion.count" do
      repeated = Arena::MusicContent.create_preview!(area: "percepcao", level: "1", kind: "mixed")
      assert_equal content.id, repeated.id
      assert_equal content.content_digest, repeated.content_digest
    end
    Arena::Catalog.stub(:validate!, ->(_) { raise Arena::InvalidContent, "Invalid frozen content" }) do
      assert_raises(Arena::InvalidContent) { Arena::MusicContent.create_preview!(area: "percepcao", level: "1", kind: "mixed") }
    end
  end

  test "all areas and levels freeze valid stimuli without exposing musical keys" do
    content = Arena::MusicContent.create_preview!(area: "all", level: "mixed")
    entries = content.body.fetch("exercises")
    assert_equal %w[harmonia leitura percepcao ritmica], entries.map { |e| e["area"] }.uniq.sort
    assert_equal [1,2,3,4], entries.map { |e| e["level"] }.uniq.sort
    entries.each { |entry| assert Arena::MusicContent.validate_entry!(entry) }
    owner = arena_user
    session = Arena::Game.create!(actor: owner, content_version: content, title: "Banda", question_count: 50, duration_seconds: 10, technical_preview: true)
    assert_empty session.arena_memberships
    assert_equal "presenter", session.presentation_mode
    session.arena_question_snapshots.each do |snapshot|
      assert Arena::MusicContent.validate_snapshot!(snapshot.payload, content_version_id: content.id)
      public_data = Arena::Projections.question(snapshot)
      refute_match(/correct_option|source_option|signature|source_status|content_version_id|"roman"|inversion|exercise/, public_data.to_json)
      assert_equal 4, public_data[:options].size
    end
    snapshot = session.arena_question_snapshots.first
    bad = snapshot.payload.deep_dup
    bad["correct_option_id"] = bad["options"].find { |o| o["id"] != bad["correct_option_id"] }.fetch("id")
    assert_raises(Arena::InvalidContent) { Arena::MusicContent.validate_snapshot!(bad, content_version_id: content.id) }
    bad = snapshot.payload.deep_dup
    bad["entry"]["level"] = 99
    assert_raises(Arena::InvalidContent) { Arena::MusicContent.validate_snapshot!(bad, content_version_id: content.id) }
  end

  test "mixed sampling balances areas instead of weighting pool sizes and avoids immediate repeats" do
    body = Arena::MusicContent.package(Arena::MusicContent.profile!(area: "all", level: "1"))
    picked = Arena::MusicContent.sample(body.fetch("exercises"), 400, random: Random.new(67))
    assert picked.all? { |e| e["level"] == 1 }
    picked.group_by { |e| e["area"] }.each_value { |group| assert_includes 65..135, group.size }
    picked.each_cons(2) { |a,b| refute_equal Arena::MusicContent.stimulus_identity(a), Arena::MusicContent.stimulus_identity(b) }
    assert_raises(Arena::InvalidContent) { Arena::MusicContent.profile!(area: "historia", level: "1") }
    assert_raises(Arena::InvalidContent) { Arena::MusicContent.profile!(area: "ritmica", level: "1", kind: "syncopation") }
  end
  test "a rendering update does not replace the notation frozen in an issued snapshot" do
    content = Arena::MusicContent.create_preview!(area: "leitura", level: "1")
    owner = arena_user
    room = Arena::Game.create!(actor: owner, content_version: content, title: "Histórico", question_count: 1, duration_seconds: 10, technical_preview: true)
    snapshot = room.arena_question_snapshots.sole
    frozen_svg = snapshot.payload.dig("stimulus","svg")
    Arena::NotationRenderer.stub(:new, ->(**) { raise "must not rerender an issued stimulus" }) do
      assert_equal frozen_svg, Arena::Projections.question(snapshot)[:svg]
    end
  end

end
