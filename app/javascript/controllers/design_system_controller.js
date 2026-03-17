import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.configureScrollRestoration();
    this.initReveal();

    // Bind the mousemove handler
    this.mouseMoveHandler = this.handleMouseMove.bind(this);
    document.addEventListener('mousemove', this.mouseMoveHandler);

    this.init3DCardHover();
    this.initScrollSteps();
    this.initLucideIcons();
  }

  disconnect() {
    if (this.mouseMoveHandler) {
      document.removeEventListener('mousemove', this.mouseMoveHandler);
    }

    if (this.scrollStepsRequestTick) {
      window.removeEventListener('scroll', this.scrollStepsRequestTick);
      window.removeEventListener('resize', this.scrollStepsRequestTick);
    }
  }

  // 1. Initial Reveal Logic (Intersection Observer)
  initReveal() {
    const revealElements = document.querySelectorAll('.reveal');
    
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            const isBidirectional = entry.target.hasAttribute('data-reveal-bidirectional') ||
              Boolean(entry.target.closest('[data-reveal-bidirectional-section]'));

            if (entry.isIntersecting) {
              entry.target.classList.add('active');

              // Default behavior for the rest of the page remains one-way.
              if (!isBidirectional) observer.unobserve(entry.target);
              return;
            }

            // Bidirectional mode: fade out when the element leaves the viewport.
            if (isBidirectional) {
              entry.target.classList.remove('active');
            }
        });
    }, { threshold: 0, rootMargin: '0px 0px -4% 0px' });

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

  initLucideIcons() {
    if (typeof lucide !== 'undefined') {
      lucide.createIcons();
    }
  }

  configureScrollRestoration() {
    if ('scrollRestoration' in history) {
      history.scrollRestoration = 'manual';
    }

    if (!window.location.hash) {
      window.scrollTo(0, 0);
    }
  }

  initScrollSteps() {
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduceMotion || window.innerWidth < 768) return;

    const wrappers = document.querySelectorAll("[data-scroll-steps]");
    if (!wrappers.length) return;

    let ticking = false;
    const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

    const update = () => {
      wrappers.forEach((wrapper) => {
        const section = wrapper.closest("section");
        const cards = wrapper.querySelectorAll(".step-card");
        if (!section || !cards.length) return;

        const vh = window.innerHeight;
        const sectionRect = section.getBoundingClientRect();
        const scrollRange = sectionRect.height + vh * 0.2;
        const scrolled = clamp((vh * 0.96) - sectionRect.top, 0, scrollRange);
        const segment = scrollRange / cards.length;

        cards.forEach((card, index) => {
          const progress = clamp((scrolled - (index * segment)) / (segment * 0.45), 0, 1);
          const opacity = 0.02 + (progress * 0.98);
          card.style.opacity = opacity.toFixed(3);
        });
      });

      ticking = false;
    };

    this.scrollStepsRequestTick = () => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(update);
    };

    window.addEventListener("scroll", this.scrollStepsRequestTick, { passive: true });
    window.addEventListener("resize", this.scrollStepsRequestTick);
    this.scrollStepsRequestTick();
  }
}
