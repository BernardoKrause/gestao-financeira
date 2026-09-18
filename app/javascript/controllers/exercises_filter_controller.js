import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  filterNow() {
    this.submit()
  }

  filterDebounced() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.submit(), 300)
  }

  submit() {
    const url = new URL(this.urlValue, window.location.origin)
    const formParams = new URLSearchParams(new FormData(this.element))
    formParams.forEach((value, key) => url.searchParams.set(key, value))

    fetch(url, { headers: { Accept: "text/vnd.turbo-stream.html" } })
      .then((response) => {
        if (!response.ok) throw new Error(`unexpected status ${response.status}`)
        return response.text()
      })
      .then((html) => Turbo.renderStreamMessage(html))
      .catch((error) => console.error("exercises-filter: failed to update list", error))
  }
}
