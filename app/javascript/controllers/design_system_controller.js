import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.initReveal();
    
    // Bind the mousemove handler
    this.mouseMoveHandler = this.handleMouseMove.bind(this);
    document.addEventListener('mousemove', this.mouseMoveHandler);

    this.init3DCardHover();
  }

  disconnect() {
    if (this.mouseMoveHandler) {
      document.removeEventListener('mousemove', this.mouseMoveHandler);
    }
  }

  // 1. Initial Reveal Logic (Intersection Observer)
  initReveal() {
    const revealElements = document.querySelectorAll('.reveal');
    
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if(entry.isIntersecting) {
                entry.target.classList.add('active');
            }
        });
    }, { threshold: 0.1 });

    revealElements.forEach(el => observer.observe(el));
  }

  // 2. Parallax Orbs & Mouse Tracking
  handleMouseMove(e) {
    const orbs = document.querySelectorAll('.orb');
    const { clientX, clientY } = e;
    const centerX = window.innerWidth / 2;
    const centerY = window.innerHeight / 2;

    orbs.forEach((orb, i) => {
        const speed = (i + 1) * 30;
        const x = (clientX - centerX) / speed;
        const y = (clientY - centerY) / speed;
        orb.style.transform = `translate(${x}px, ${y}px)`;
    });

    // Flashlight cards
    const flashCards = document.querySelectorAll('.flash-card');
    flashCards.forEach(card => {
        const rect = card.getBoundingClientRect();
        const x = clientX - rect.left;
        const y = clientY - rect.top;
        card.style.setProperty('--mouse-x', `${x}px`);
        card.style.setProperty('--mouse-y', `${y}px`);
    });
  }

  // 3. 3D Card Hover Logic
  init3DCardHover() {
    const glassCards = document.querySelectorAll('.glass-3d');
    glassCards.forEach(card => {
        card.addEventListener('mousemove', (e) => {
            const rect = card.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            const centerX = rect.width / 2;
            const centerY = rect.height / 2;
            // The magic numbers control the intensity of the tilt
            const rotateX = (centerY - y) / 10;
            const rotateY = (x - centerX) / 10;
            card.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale3d(1.02, 1.02, 1.02)`;
        });

        card.addEventListener('mouseleave', () => {
            card.style.transform = `perspective(1000px) rotateX(0deg) rotateY(0deg) scale3d(1, 1, 1)`;
        });
    });
  }
}
