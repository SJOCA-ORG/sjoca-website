import { Controller } from "@hotwired/stimulus"

// An embedded map captures scroll gestures, which on a phone means the page
// stops moving when your thumb crosses it. The iframe stays inert until it is
// deliberately clicked.
export default class extends Controller {
  activate() { this.element.classList.add("is-active") }
}
