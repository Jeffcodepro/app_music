module ArenaHelper
  def arena_answer_figure(index)
    paths = [
      "M19 20V5",
      "M19 20V5c0 6 8 4 5 11",
      "M11 21V7l16-3v15M11 11l16-3M11 7l16-3",
      "M19 20V4c0 5 8 3 5 9M19 9c0 5 8 3 5 9"
    ]
    tag.svg(viewBox: "0 0 36 32", "aria-hidden": true, focusable: "false", class: "arena-answer-figure") do
      heads = index == 2 ? [[7,23],[23,21]] : [[15,22]]
      safe_join(heads.map { |x,y| tag.ellipse(cx: x, cy: y, rx: 4.7, ry: 3.2, transform: "rotate(-20 #{x} #{y})", fill: "currentColor") } +
        [tag.path(d: paths.fetch(index), fill: "none", stroke: "currentColor", "stroke-width": 2.2, "stroke-linecap": "round", "stroke-linejoin": "round")])
    end
  end

  def arena_invite_url(code)
    origin = ENV["APP_MUSIC_ARENA_PUBLIC_URL"].presence || request.base_url
    URI.join(origin, app_arena_path(code: code)).to_s
  end

  def arena_invite_qr(url)
    modules = RQRCodeCore::QRCode.new(url, level: :m).modules
    size = modules.size + 8 # Four-module quiet zone on every side, also in dark mode.
    path = modules.each_with_index.flat_map do |row, y|
      row.each_with_index.filter_map { |dark, x| "M#{x + 4},#{y + 4}h1v1h-1z" if dark }
    end.join
    tag.svg(viewBox: "0 0 #{size} #{size}", role: "img", "aria-label": "QR code para entrar na sala", "data-arena-invite-qr": true) do
      safe_join([tag.rect(width: size, height: size, fill: "#fff"), tag.path(d: path, fill: "#111", "shape-rendering": "crispEdges")])
    end
  end

  def arena_session_state_label(state)
    { "draft" => "Preparando", "lobby_open" => "Entrada aberta", "lobby_locked" => "Entrada fechada", "live" => "Em andamento",
      "paused" => "Pausada", "interrupted" => "Interrompida", "completed" => "Concluída", "cancelled" => "Encerrada", "expired" => "Expirada" }.fetch(state, "Indisponível")
  end

  def arena_host_commands(state)
    commands = []
    if %w[lobby_open lobby_locked].include?(state[:state]) && state[:phase] != "audio_check"
      commands << ["start", "Iniciar sessão"]
    elsif state[:state] == "live"
      commands << ["close", "Encerrar questão"] if state.dig(:round,:state) == "answering"
      commands << ["explain", "Explicar resposta"] if %w[answering results].include?(state.dig(:round,:state))
      commands << ["next", state.dig(:round,:position) == state[:question_count] ? "Concluir sessão" : "Próxima questão"] if %w[results void].include?(state.dig(:round,:state))
      commands << ["pause", "Pausar"]
    elsif state[:state] == "paused"
      commands << ["resume", "Retomar"]
      commands << ["explain", "Explicar resposta"] if state.dig(:round,:state) == "paused" && state.dig(:round,:paused_from) == "answering"
      commands << ["next", state.dig(:round,:position) == state[:question_count] ? "Concluir sessão" : "Próxima questão"] if %w[results void].include?(state.dig(:round,:state))
    end
    commands << ["void", "Anular questão"] if %w[live paused].include?(state[:state]) && %w[ready answering paused].include?(state.dig(:round,:state))
    commands << ["end", "Encerrar sessão"]
    commands
  end
end
