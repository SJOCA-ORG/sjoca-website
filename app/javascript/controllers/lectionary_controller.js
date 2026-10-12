import { Controller } from "@hotwired/stimulus"

// Verse numbers off by default — scripture reads better as prose — with the
// choice remembered so nobody has to make it twice.
//
// A cookie rather than localStorage: this is a reading preference the server
// may well want to honour later (in a printed bulletin, say), and a cookie is
// the only client-side store it can see.
export default class extends Controller {
  static targets = ["button"]
  static KEY = "verse_numbers"

  connect() {
    this.on = this.#read() === "1"
    this.#apply()
  }

  toggle() {
    this.on = !this.on
    this.#write(this.on ? "1" : "0")
    this.#apply()
  }

  #apply() {
    this.element.classList.toggle("show-verse-numbers", this.on)
    if (this.hasButtonTarget) {
      this.buttonTarget.textContent = this.on ? "Hide verse numbers" : "Show verse numbers"
      this.buttonTarget.setAttribute("aria-pressed", String(this.on))
    }
  }

  #read() {
    const m = document.cookie.match(new RegExp("(?:^|; )" + this.constructor.KEY + "=([^;]*)"))
    return m ? decodeURIComponent(m[1]) : null
  }

  #write(value) {
    // A year, site-wide, and SameSite=Lax: a preference, not a tracker.
    document.cookie =
      `${this.constructor.KEY}=${value}; path=/; max-age=31536000; SameSite=Lax`
  }
}
