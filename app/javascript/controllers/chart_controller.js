import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { labels: Array, datasets: Array }

  async connect() {
    const { default: Chart } = await import("chart.js")
    if (!this.element.isConnected) return

    this.chart = new Chart(this.element, {
      type: "line",
      data: {
        labels: this.labelsValue,
        datasets: this.datasetsValue
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: true } }
      }
    })
  }

  disconnect() {
    this.chart?.destroy()
  }
}
