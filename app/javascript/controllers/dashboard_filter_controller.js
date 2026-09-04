import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]
  static values = { url: String }

  filter(event) {
    const level = event.params.level

    this.buttonTargets.forEach((button) => {
      const active = button.dataset.dashboardFilterLevelParam === level
      button.classList.toggle("bg-slate-900", active)
      button.classList.toggle("text-white", active)
      button.classList.toggle("text-slate-600", !active)
      button.classList.toggle("hover:bg-slate-100", !active)
    })

    fetch(`${this.urlValue}?confidence=${level}`, {
      headers: { Accept: "text/vnd.turbo-stream.html" }
    })
      .then((response) => {
        if (!response.ok) throw new Error(`unexpected status ${response.status}`)
        return response.text()
      })
      .then((html) => Turbo.renderStreamMessage(html))
      .catch((error) => console.error("dashboard-filter: failed to update KPI card", error))
  }
}
