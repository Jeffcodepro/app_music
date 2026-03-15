import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // O usuário optou por remover o Video Scrubbing via JS devido a travamentos de decodificação.
  // Este arquivo permanece limpo/ativo no manifest caso seja necessário futuramente.
  connect() {
    // A tag de vídeo agora usa nativamente autoplay, loop, e muted no ERB.
  }
}
