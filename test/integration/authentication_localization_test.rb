require "test_helper"

class AuthenticationLocalizationTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "recovery presents the same localized response for known and unknown email" do
    user = User.create!(email: "recovery@example.test", password: "password123", full_name: "Teste")
    assert_emails 0 do
      post user_password_path, params: { user: { email: "unknown@example.test" } }
    end
    unknown = [response.status, response.location, flash[:notice]]
    assert_emails 1 do
      post user_password_path, params: { user: { email: user.email } }
    end
    assert_equal unknown, [response.status, response.location, flash[:notice]]
    assert_match(/Se houver uma conta/, flash[:notice])
    assert user.reload.reset_password_token.present?
  end

  test "login failure and registration validation are localized without weakening requirements" do
    post user_session_path, params: { user: { email: "unknown@example.test", password: "incorrect" } }
    follow_redirect! if response.redirect?
    assert_match(/E-mail ou senha inválidos/, response.body)
    post user_registration_path, params: { user: { email: "invalid", password: "short", password_confirmation: "different" } }
    assert_response :unprocessable_entity
    assert_match(/não é válido/, response.body)
    assert_match(/muito curta|mínimo/, response.body)
    refute_match(/translation missing|Please review|is invalid|is too short/i, response.body)
  end

  test "existing English recovery email content remains unchanged under the Portuguese UI locale" do
    user = User.create!(email: "mail-contract@example.test", password: "password123", full_name: "Teste")
    { reset_password_instructions: [user, "synthetic-token"], email_changed: [user], password_change: [user] }.each do |action, arguments|
      original = I18n.with_locale(:en) { Devise.mailer.public_send(action, *arguments).message }
      localized = I18n.with_locale(:"pt-BR") { Devise.mailer.public_send(action, *arguments).message }
      assert_equal original.subject, localized.subject, action.to_s
      assert_equal original.body.decoded, localized.body.decoded, action.to_s
      assert_equal original.to, localized.to, action.to_s
    end
    %w[confirmation_instructions reset_password_instructions unlock_instructions email_changed password_change].each do |action|
      assert_equal I18n.t("devise.mailer.#{action}.subject", locale: :en), I18n.t("devise.mailer.#{action}.subject", locale: :"pt-BR")
    end
  end
end
