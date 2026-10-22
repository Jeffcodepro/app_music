require "test_helper"

class PublicExperienceTest < ActionDispatch::IntegrationTest
  test "landing preserves the original visual composition with a fixed public theme and no theme selectors" do
    get root_path
    assert_response :success
    assert_select "body.landing-body[data-controller=theme]", count: 1
    assert_select "h1", count: 1
    assert_select "body[data-theme-fixed-value=light]", count: 1
    assert_select "select[aria-label='Tema da interface'], .theme-picker", count: 0
    assert_select ".landing-evolution-copy", count: 1
    assert_select ".landing-evolution-copy[class*='bg-'], .landing-evolution-copy[class*=backdrop]", count: 0
    assert_select "a[href='#{new_user_registration_path}']", minimum: 1
    assert_select "a[href='#{new_user_session_path}']", minimum: 1
    %w[hero vantagens problema como-funciona modos-estudo playgrounds gamificacao diversao conteudo diferenciais planos faq cta].each do |id|
      assert_select "section##{id}", count: 1
    end
    assert_select "#hero video", count: 2
    assert_select "#hero video[src*='Sheet_music_looping_motion_graphic']", count: 2
    assert_select "h1", text: /Teoria Musical.*No Ponto Certo/m
    assert_select ".landing-nav.glass-static, .public-score, a button", count: 0
    assert_select ".landing-nav .glass-static", count: 1
    refute_match(/Caderno de Ensaio|Encontre seu foco de hoje/, response.body)
  end

  test "available navigation includes Arena with account at the bottom and future resources separate" do
    user = User.create!(email: "navigation@example.test", password: "password123", full_name: "Teste", plan: "Pulso")
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    get app_practice_result_path
    assert_select "nav[aria-label='Navegação principal'] a", count: 5
    assert_select "nav[aria-label='Navegação principal'] a[href='#{app_arena_path}']", count: 1
    assert_select ".sidebar-bottom a[href='#{app_perfil_path}']", count: 1
    assert_select "nav[aria-label='Navegação principal'] a[aria-current=page][href='#{app_practice_result_path}']", count: 1
    assert_select "nav[aria-label='Em preparação'] a", count: 2
  end

  test "all audible exercises expose neutral playback status without changing answer identity" do
    user = User.create!(email: "audio-status@example.test", password: "password123", full_name: "Teste", plan: "Pulso")
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    { "percepcao" => "interval", "ritmica" => "rhythm", "harmonia" => "harmony" }.each do |area, player|
      get app_playground_path(activity: area)
      assert_select "[data-#{player}-player-target=status][role=status]", text: "Pronto para ouvir"
      assert_select "form[action='#{submit_app_playground_answer_path}'] input[name=assignment_id]", count: 4
      assert_select "input[name=correct_option_id], input[name=xp]", count: 0
    end
  end
end
