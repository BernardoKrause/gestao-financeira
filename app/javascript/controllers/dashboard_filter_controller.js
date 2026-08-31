import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  filter(event) {
    const level = event.params.level

    this.buttonTargets.forEach((button) => {
      const active = button.dataset.dashboardFilterLevelParam === level
      button.classList.toggle("bg-slate-900", active)
      button.classList.toggle("text-white", active)
      button.classList.toggle("text-slate-600", !active)
    })

    fetch(`/dashboard_confidence?confidence=${level}`, {
      headers: { Accept: "text/vnd.turbo-stream.html" }
    })
      .then((response) => response.text())
      .then((html) => Turbo.renderStreamMessage(html))
  }
}
