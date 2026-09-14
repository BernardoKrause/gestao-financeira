import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  async connect() {
    const { default: Sortable } = await import("sortablejs")
    if (!this.element.isConnected) return

    this.sortable = new Sortable(this.element, {
      animation: 150,
      handle: "[data-sortable-handle]",
      onEnd: () => this.persistOrder()
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  persistOrder() {
    const ids = Array.from(this.element.children).map((el) => el.dataset.sortableId)

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ ids })
    }).catch((error) => console.error("sortable: failed to persist order", error))
  }
}
