import { Controller } from "@hotwired/stimulus"

// Selection is local preview only. Membership is created by the final POST.
export default class extends Controller {
  static targets = ["characters", "profile", "preview", "nickname", "settings", "confirm", "advance", "back", "stepLabel"]

  connect() {
    this.stage = this.selected() ? "profile" : "character"
    this.render()
  }
  selected() { return this.charactersTarget.querySelector("input:checked") }
  choose() {
    this.advanceTarget.disabled = !this.selected()
    this.renderPreview()
  }
  next() {
    if (!this.selected()) return
    this.stage = "profile"
    this.render()
    this.nicknameTarget.focus()
  }
  submit(event) {
    if (this.stage !== "profile") { event.preventDefault(); this.next() }
  }
  back() {
    this.stage = "character"
    this.render()
    this.selected()?.focus()
  }
  renderPreview() {
    const checked = this.selected()
    const drawing = checked?.parentElement.querySelector("svg")
    this.previewTarget.replaceChildren(...(drawing ? [drawing.cloneNode(true)] : []))
  }
  render() {
    const profile = this.stage === "profile"
    this.charactersTarget.hidden = profile
    this.profileTarget.hidden = !profile
    this.nicknameTarget.required = profile
    this.settingsTarget.querySelectorAll("[required], [data-identity-required]").forEach(input => { input.dataset.identityRequired = "true"; input.required = profile })
    this.settingsTarget.hidden = !profile
    this.confirmTarget.hidden = !profile
    this.advanceTarget.hidden = profile
    this.advanceTarget.disabled = !this.selected()
    this.backTarget.hidden = !profile
    this.stepLabelTarget.textContent = profile ? "1 · Personagem escolhido ✓" : "1 · Personagem"
    this.renderPreview()
  }
}
