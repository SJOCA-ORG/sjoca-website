import { Controller } from "@hotwired/stimulus"

// Mobile menu toggle. The desktop menu is CSS-only (hover/focus-within), so
// this only has to deal with the narrow layout.
export default class extends Controller {
  static targets = ["menu"]

  toggle(event) {
    const open = this.menuTarget.classList.toggle("is-open")
    event.currentTarget.setAttribute("aria-expanded", String(open))
  }
}
