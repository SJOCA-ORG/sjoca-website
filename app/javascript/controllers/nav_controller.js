import { Controller } from "@hotwired/stimulus"

// Mobile menu toggle. The desktop menu is CSS-only (hover/focus-within), so
// this only has to deal with the narrow layout.
export default class extends Controller {
  static targets = ["menu"]

  // On a phone the submenus start closed so the menu fits the screen. Tapping
  // the caret opens one; tapping the label still follows the link, because
  // these parents have pages of their own.
  expand(event) {
    event.preventDefault()
    event.stopPropagation()
    event.currentTarget.closest(".site-nav__item").classList.toggle("is-expanded")
  }

  toggle(event) {
    const open = this.menuTarget.classList.toggle("is-open")
    event.currentTarget.setAttribute("aria-expanded", String(open))
  }
}
