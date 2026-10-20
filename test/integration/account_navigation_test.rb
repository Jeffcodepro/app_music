require "test_helper"
require "minitest/mock"

class AccountNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "account-pages@example.test", password: "password123", full_name: "Estudante", plan: "Pulso")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end

  test "account is at the sidebar bottom and uses separate accessible pages" do
    get app_perfil_path
    assert_select ".app-topbar a.profile-link", count: 0
    assert_select ".sidebar-bottom a[href='#{app_perfil_path}']", count: 1
    assert_select "nav[aria-label='Navegação principal'] a[href='#{app_perfil_path}']", count: 0
    assert_select "[data-account-section=overview]", count: 1
    %w[dados-pessoais assinaturas notificacoes aparencia].each do |section|
      get "/app/perfil/#{section}"
      assert_response :success
      assert_select ".account-links a[aria-current=page]", count: 1
      assert_select "h1", count: 1
      assert_select "title", text: "Minha conta · AppMusic"
      assert_select "[href*=certificado], input[type=checkbox]", count: 0
    end
  end

  test "personal data allowlist and credentials validation stay separate" do
    patch update_app_perfil_path, params: { user: { full_name: "Nome atualizado", email: "forged@example.test", plan: "Maestro", password: "forged123", id: 999 } }
    assert_redirected_to "/app/perfil/dados-pessoais"
    assert_equal "Nome atualizado", @user.reload.full_name
    assert_equal "account-pages@example.test", @user.email
    assert_equal "Pulso", @user.plan
    assert @user.valid_password?("password123")
    put user_registration_path, params: { user: { email: "unsafe@example.test", current_password: "wrong" } }
    assert_response :unprocessable_entity
    assert_select ".account-links", count: 1
    assert_select "input[name='user[current_password]']", count: 1
    assert_equal "account-pages@example.test", @user.reload.email
  end

  test "new account pages require authentication" do
    delete destroy_user_session_path
    %w[dados-pessoais assinaturas notificacoes aparencia].each do |section|
      get "/app/perfil/#{section}"
      assert_redirected_to new_user_session_path
    end
  end

  test "dashboard metrics precede the practice content and calendar has real dates" do
    get app_dashboard_path
    assert_operator response.body.index('class="study-record"'), :<, response.body.index('class="study-desk"')
    assert_select "[data-testid=study-calendar] time[datetime]", minimum: 28
    assert_select "[data-sidebar-panel-icon]", count: 1
    refute_match(/translation missing/i, response.body)
  end

  test "unavailable daily access recording does not prevent account or practice access" do
    DailyVisit.stub(:record_for, ->(*) { raise ActiveRecord::StatementInvalid, "unavailable" }) do
      [app_dashboard_path, app_pratica_path, app_perfil_path].each do |path|
        get path
        assert_response :success
      end
    end
    assert_equal 0, @user.study_activities.sum(:xp_earned)
  end
end
