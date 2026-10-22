require "test_helper"
require "minitest/mock"
require_relative "../../support/arena_foundation_helpers"

class ArenaClassroomFlowTest < ActionDispatch::IntegrationTest
  include ArenaFoundationHelpers
  setup do
    @host,@student,@other = arena_user,arena_user,arena_user
    @room = Arena::Game.create!(actor: @host, content_version: Arena::Catalog.create_preview!, title: "Aula em jogo", question_count: 2,
      duration_seconds: 30, technical_preview: true, experience: "party", host_nickname: "Maestro")
    @member = Arena::Join.call(actor: @student, code: Arena::Invites.code(@room), nickname: "-Sabiá", avatar_id: "cat")
    @owner,@player,@outsider = open_session,open_session,open_session
    [[@owner,@host],[@player,@student],[@outsider,@other]].each do |client,user|
      client.post user_session_path, params: { user: { email: user.email, password: "isolated-arena-password" } }
    end
  end
  def command(name)
    Arena::Game.command!(actor: @host, session: @room, command: name, expected_version: @room.reload.lock_version)
  end
  def answering
    command("start")
    round = @room.arena_rounds.find_by!(position: 1)
    round.update!(answer_open_at: 1.second.ago, deadline_at: 30.seconds.from_now)
    Arena::Game.settle!(actor: @host, session: @room)
    round.reload
  end

  test "host controls are visible and guest has only a private leave action" do
    round = answering
    @owner.get app_arena_session_path(@room)
    assert_equal 200, @owner.response.status
    doc = Nokogiri::HTML(@owner.response.body)
    assert doc.at_css('section.arena-control-bar button[data-arena-command="pause"]')
    assert doc.at_css('button[data-arena-command="close"]')
    assert doc.at_css('button[data-arena-command="explain"]')
    refute doc.at_css('details.arena-director')
    @player.get app_arena_session_path(@room)
    refute Nokogiri::HTML(@player.response.body).at_css('.arena-control-bar')
    assert Nokogiri::HTML(@player.response.body).at_css("form[action='#{leave_app_arena_session_path(@room)}']")
    %w[pause explain close finish].each do |action|
      @player.post command_app_arena_session_path(@room), params: { command: action, version: @room.reload.lock_version }
      assert_equal 404, @player.response.status
    end
    assert_equal "answering", round.reload.state
    command("explain")
    @owner.get app_arena_session_path(@room)
    assert_includes @owner.response.body, "Pausa para a explicação"
    assert Nokogiri::HTML(@owner.response.body).at_css('button[data-arena-command="next"]')
  end

  test "report is private frozen escaped and CSV cannot execute nickname as a formula" do
    round = answering
    Arena::RecordAnswer.call(actor: @student, round: round, option_id: round.arena_question_snapshot.payload["correct_option_id"], idempotency_key: SecureRandom.uuid)
    command("finish")
    @owner.get app_arena_session_path(@room)
    refute Nokogiri::HTML(@owner.response.body).at_css('.arena-game-stats')
    @owner.get report_app_arena_session_path(@room)
    assert_equal 200, @owner.response.status
    assert_includes @owner.response.body, "Cada pessoa, seu percurso"
    assert_includes @owner.response.body, "-Sabiá"
    refute_includes @owner.response.body, @student.email
    refute_includes Nokogiri::HTML(@owner.response.body).at_css('.arena-report').to_html, @host.email
    @owner.get report_app_arena_session_path(@room, format: :csv)
    assert_equal 200, @owner.response.status
    assert_includes @owner.response.headers["Content-Type"], "text/csv"
    assert_includes @owner.response.body, "'-Sabiá"
    assert_includes @owner.response.headers["Cache-Control"], "no-store"
    [@player,@outsider].each do |client|
      [:html,:csv].each do |format|
        client.get report_app_arena_session_path(@room, format: format)
        assert_equal 404, client.response.status
      end
    end
  end

  test "leaving keeps the room in history and terminal podium but never gives control or future questions" do
    round = answering
    Arena::RecordAnswer.call(actor: @student, round: round, option_id: round.arena_question_snapshot.payload["correct_option_id"], idempotency_key: SecureRandom.uuid)
    @player.post leave_app_arena_session_path(@room)
    assert_equal 303, @player.response.status
    assert_equal app_arena_path, URI(@player.response.location).path
    @player.get app_arena_session_path(@room, format: :json)
    assert_equal 200, @player.response.status
    assert @player.response.parsed_body["departed"]
    refute @player.response.parsed_body.key?("round")
    @player.post settle_app_arena_session_path(@room)
    assert_equal 404, @player.response.status
    command("finish")
    @player.get app_arena_session_path(@room)
    assert_equal 200, @player.response.status
    assert Nokogiri::HTML(@player.response.body).at_css('.arena-podium')
    refute_includes @player.response.body, "Relatório dos participantes"
    @player.get app_arena_path
    assert Nokogiri::HTML(@player.response.body).at_css("a[href='#{app_arena_session_path(@room)}']")
  end
end
