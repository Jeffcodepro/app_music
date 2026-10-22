require "test_helper"
require "minitest/mock"
require_relative "../../support/arena_foundation_helpers"

class ArenaVisualContentTest < ActiveSupport::TestCase
  include ArenaFoundationHelpers

  test "three visual topics expose four real levels and all supported clefs with independent validation" do
    packages = Arena::Catalog.create_visual_previews!
    assert_equal 12, packages.size
    packages.each do |content|
      assert Arena::Catalog.validate!(content)
      profile = content.body.fetch("profile")
      assert_equal "reading-visual-v2", content.body.fetch("type")
      assert_includes %w[level_1 level_2 level_3 level_4], profile.fetch("level")
      assert_equal %w[alto bass treble], content.body.fetch("exercises").map { |exercise| exercise["clef_id"] }.uniq.sort
      assert_operator content.body.fetch("exercises").size, :>=, 9
      content.body.fetch("exercises").each do |exercise|
        assert ExerciseIntegrityValidator.validate!("leitura", exercise)
        assert_equal profile.fetch("level"), exercise.fetch("season_id")
        assert_equal profile.fetch("question_type"), exercise.fetch("question_type")
      end
    end
  end

  test "new snapshots use exact source neutral vector notation and opaque shuffled choices" do
    content = Arena::Catalog.create_visual_previews!.find { |row| row.body.dig("profile","level") == "level_3" && row.body.dig("profile","question_type") == "accidental" }
    host = arena_user
    room = Arena::Game.create!(actor: host, content_version: content, title: "Leitura variada", question_count: 9, duration_seconds: 30, technical_preview: true)
    assert_equal 9, room.arena_rounds.count
    assert_equal ["reading-visual-v2"], room.arena_question_snapshots.pluck(:payload_version).uniq
    room.arena_question_snapshots.each do |snapshot|
      assert_equal 4, snapshot.option_ids.uniq.size
      assert_equal 4, snapshot.payload.fetch("options").map { |option| option["label"] }.uniq.size
      svg = snapshot.payload.fetch("svg")
      refute_match(/<script|<foreignObject|<image|font-family/, svg)
      assert_includes svg, 'data-arena-notation="v2"'
      original = Arena::Projections.question(snapshot)
      Arena::NotationRenderer.stub(:new, ->(*) { raise "future renderer" }) do
        assert_equal original, Arena::Projections.question(snapshot)
      end
    end
    payload = room.arena_question_snapshots.first.payload.deep_dup
    payload["exercise"]["season_id"] = "level_1"
    assert_raises(Arena::InvalidContent) { Arena::ReadingVisualContent.validate_snapshot!(payload, content_version_id: content.id) }
  end

  test "level contracts reject relabeling out of range accidentals and unsupported profile" do
    exercise = ReadingNoteExerciseGenerator.new(clef_mode: "treble", question_mode: "note_name", season_mode: "level_4", random: Random.new(44)).call.deep_stringify_keys
    exercise["season_id"] = "level_1"
    exercise["season_mode"] = "level_1"
    exercise["season_label"] = "Nível 1"
    exercise["staff_position_index"] = 14
    assert_raises(Arena::InvalidContent) { Arena::ReadingVisualContent.validate!(exercise, profile: { "level" => "level_1", "question_type" => "note_name", "clefs" => %w[treble bass alto] }) }
    assert_raises(Arena::InvalidContent) { Arena::ReadingVisualContent.package(level: "level_5", question_type: "note_name") }
  end

  test "new database contract rejects unbound visual snapshots and retains history immutability" do
    host = arena_user
    room = arena_session(host)
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaQuestionSnapshot.transaction(requires_new: true) do
        ArenaQuestionSnapshot.insert_all!([{ id: SecureRandom.uuid, arena_session_id: room.id, payload_version: "reading-visual-v2",
          payload_digest: "a" * 64, payload: arena_payload, created_at: Time.current }])
      end
    end
  end

  test "visual profile rejects a contradictory clef label" do
    body = Arena::ReadingVisualContent.package(level: "level_1", question_type: "note_name")
    exercise = body.fetch("exercises").first.merge("clef_label" => "Clave de Fá")
    assert_raises(Arena::InvalidContent) { Arena::ReadingVisualContent.validate!(exercise, profile: body["profile"]) }
  end

  test "non applicable fields cannot disguise a repeated musical stimulus" do
    body = Arena::ReadingVisualContent.package(level: "level_1", question_type: "note_name")
    exercise = body.fetch("exercises").first.merge("key_signature_id" => "g_major")
    assert_raises(Arena::InvalidContent) { Arena::ReadingVisualContent.validate!(exercise, profile: body["profile"]) }
    body = Arena::ReadingVisualContent.package(level: "level_1", question_type: "key_signature")
    exercise = body.fetch("exercises").first.merge("staff_position_index" => 2)
    assert_raises(Arena::InvalidContent) { Arena::ReadingVisualContent.validate!(exercise, profile: body["profile"]) }
  end

  test "accidental distractors respect the same level range as the correct response" do
    body = Arena::ReadingVisualContent.package(level: "level_1", question_type: "accidental")
    exercise = body.fetch("exercises").first.deep_dup
    option = exercise.fetch("options").find { |value| value["id"] != exercise["correct_option_id"] }
    reference = ReadingNoteExerciseGenerator.accidental_note_option("c__double_sharp")
    option.replace(reference.slice(:id,:label).stringify_keys)
    assert_raises(Arena::InvalidContent) { Arena::ReadingVisualContent.validate!(exercise, profile: body["profile"]) }
  end
end
