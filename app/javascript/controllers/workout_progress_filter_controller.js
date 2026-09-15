import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["exercise", "periodButton"]
  static values = { url: String }

  changeExercise() {
    this.fetchChart({ exercise_id: this.exerciseTarget.value, period: this.activePeriod() })
  }

  changePeriod(event) {
    const period = event.params.period

    this.periodButtonTargets.forEach((button) => {
      const active = button.dataset.workoutProgressFilterPeriodParam === period
      button.classList.toggle("bg-slate-900", active)
      button.classList.toggle("text-white", active)
      button.classList.toggle("text-slate-600", !active)
      button.classList.toggle("hover:bg-slate-100", !active)
    })

    this.fetchChart({ exercise_id: this.exerciseTarget.value, period })
  }

  activePeriod() {
    const active = this.periodButtonTargets.find((button) => button.classList.contains("bg-slate-900"))
    return active?.dataset.workoutProgressFilterPeriodParam || "3m"
  }

  fetchChart({ exercise_id, period }) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("exercise_id", exercise_id)
    url.searchParams.set("period", period)

    fetch(url, { headers: { Accept: "text/vnd.turbo-stream.html" } })
      .then((response) => {
        if (!response.ok) throw new Error(`unexpected status ${response.status}`)
        return response.text()
      })
      .then((html) => Turbo.renderStreamMessage(html))
      .catch((error) => console.error("workout-progress-filter: failed to update chart", error))
  }
}
