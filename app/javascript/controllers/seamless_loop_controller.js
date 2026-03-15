import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["primary", "secondary"]

  connect() {
    this.fadeDuration = 3.5; 
    
    // Tentamos fazer o play inicial
    this.primaryTarget.play().catch(() => {});
    
    // Só ligamos a escuta no primaryTarget. 
    // Quando ele estiver acabando, cruzamos pro secondary.
    // Quando o secondary estiver acabando, cruzamos de volta pro primary.
    this.primaryHandler = () => this.checkFade(this.primaryTarget, this.secondaryTarget, true);
    this.secondaryHandler = () => this.checkFade(this.secondaryTarget, this.primaryTarget, false);

    this.primaryTarget.addEventListener('timeupdate', this.primaryHandler);
    this.secondaryTarget.addEventListener('timeupdate', this.secondaryHandler);
  }

  disconnect() {
    this.primaryTarget.removeEventListener('timeupdate', this.primaryHandler);
    this.secondaryTarget.removeEventListener('timeupdate', this.secondaryHandler);
  }

  checkFade(activeVideo, standbyVideo, isPrimaryToSecondary) {
    if (!activeVideo.duration) return;

    const timeRemaining = activeVideo.duration - activeVideo.currentTime;
    
    if (timeRemaining <= this.fadeDuration && standbyVideo.paused) {
      standbyVideo.currentTime = 0;
      standbyVideo.play().catch(() => {});

      // Transição Limpa (GPU-Accelerated)
      // Delegamos a Matemática do Fade 100% para o CSS ao invés do Javascript.
      if (isPrimaryToSecondary) {
         this.element.classList.add('fading');
      } else {
         this.element.classList.remove('fading');
      }

      // Parar o vídeo antigo logo após o CSS terminar a transição (mais folga na CPU)
      setTimeout(() => {
        activeVideo.pause();
      }, this.fadeDuration * 1000);
    }
  }
}
