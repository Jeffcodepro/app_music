import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["primary", "secondary"]

  connect() {
    this.fadeDuration = 3.5;
    this.timers = new Set();
    this.motion = window.matchMedia("(prefers-reduced-motion: reduce)");
    this.motionChanged = () => {
      this.timers.forEach(timer => clearTimeout(timer));
      this.timers.clear();
      if (this.motion.matches) { this.primaryTarget.pause(); this.secondaryTarget.pause(); }
      else {
        this.element.classList.remove("fading");
        this.secondaryTarget.pause();
        this.primaryTarget.play().catch(() => {});
      }
    };
    this.motion.addEventListener("change", this.motionChanged);

    // Tentamos fazer o play inicial
    if (!this.motion.matches) this.primaryTarget.play().catch(() => {});

    // Só ligamos a escuta no primaryTarget.
    // Quando ele estiver acabando, cruzamos pro secondary.
    // Quando o secondary estiver acabando, cruzamos de volta pro primary.
    this.primaryHandler = () => this.checkFade(this.primaryTarget, this.secondaryTarget, true);
    this.secondaryHandler = () => this.checkFade(this.secondaryTarget, this.primaryTarget, false);

    this.primaryTarget.addEventListener('timeupdate', this.primaryHandler);
    this.secondaryTarget.addEventListener('timeupdate', this.secondaryHandler);
  }

  disconnect() {
    this.motion.removeEventListener("change", this.motionChanged);
    this.timers.forEach(timer => clearTimeout(timer));
    this.primaryTarget.pause();
    this.secondaryTarget.pause();
    this.primaryTarget.removeEventListener('timeupdate', this.primaryHandler);
    this.secondaryTarget.removeEventListener('timeupdate', this.secondaryHandler);
  }

  checkFade(activeVideo, standbyVideo, isPrimaryToSecondary) {
    if (this.motion.matches || !Number.isFinite(activeVideo.duration) || activeVideo.duration <= 0) return;

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
      const timer = setTimeout(() => {
        activeVideo.pause();
        this.timers.delete(timer);
      }, this.fadeDuration * 1000);
      this.timers.add(timer);
    }
  }
}
