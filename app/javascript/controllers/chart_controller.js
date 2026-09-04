import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { labels: Array, historical: Array, projected: Array }

  async connect() {
    const { default: Chart } = await import("chart.js")
    if (!this.element.isConnected) return

    this.chart = new Chart(this.element, {
      type: "line",
      data: {
        labels: this.labelsValue,
        datasets: [
          {
            label: "Histórico Realizado",
            data: this.historicalValue,
            borderColor: "#10b981",
            backgroundColor: "rgba(16, 185, 129, 0.1)",
            fill: true,
            tension: 0.3,
            spanGaps: false
          },
          {
            label: "Projeção Futura",
            data: this.projectedValue,
            borderColor: "#64748b",
            borderDash: [ 5, 5 ],
            fill: false,
            tension: 0.3,
            spanGaps: false
          }
        ]
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
