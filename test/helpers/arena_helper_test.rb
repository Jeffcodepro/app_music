require "test_helper"

class ArenaHelperTest < ActionView::TestCase
  include ArenaHelper

  test "invitation QR has a white quiet zone and scales as an SVG" do
    html = arena_invite_qr("http://127.0.0.1:3001/app/arena?code=ABCD1234EFGH5678")
    document = Nokogiri::HTML.fragment(html)
    svg = document.at_css("svg[data-arena-invite-qr]")
    assert svg
    assert_equal "img", svg["role"]
    assert_equal "QR code para entrar na sala", svg["aria-label"]
    assert_equal "#fff", svg.at_css("rect")["fill"]
    assert svg.at_css("path")["d"].start_with?("M4,4")
    refute_includes html, "http"
    refute document.at_css("script, image, foreignObject")
  end
end
