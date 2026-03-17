require "test_helper"

class PerceptionPlaygroundFlowTest < ActionDispatch::IntegrationTest
  setup do
    @password = "password123"
    @user = User.create!(
      email: "playground@example.com",
      password: @password,
      password_confirmation: @password,
      full_name: "Aluno Playground",
      plan: "Pulso"
    )
  end

  test "renders the perception playground for an authenticated user" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "percepcao")

    assert_response :success
    assert_includes response.body, "Playground de percep"
    assert_includes response.body, "Identifique o intervalo melódico"
    assert_includes response.body, "Ouvir intervalo"
  end
end
