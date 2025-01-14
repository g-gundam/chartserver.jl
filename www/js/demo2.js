// Goals
// - dynamic chart construction based on server-side chart config
// - realtime data consumption

// INFO: Not implementing it this time.
function createLayout() {
}

function createChart(config) {
  const series = {}
  const el = document.createElement('div')
  el.classList.add("chart")
  const chart = LightweightCharts.createChart(el, config)
  Object.keys(config._series).forEach((k) => {
    const seriesConfig = config._series[k]
    switch (seriesConfig._type) {
    case "ohlc":
      series[k] = chart.addCandlestickSeries(seriesConfig)
      break;
    case "line":
      series[k] = chart.addLineSeries(seriesConfig)
      break;
    }
  })
  return { el, chart, series }
}

document.addEventListener('DOMContentLoaded', async () => {
  console.info("Now what?")

  // fetch charts
  const res = await fetch("/demo2/charts")
  const chartConfigs = await res.json()

  const charts = chartConfigs.map(createChart)

  // append to #workspace
  const workspace = document.getElementById("workspace")
  charts.forEach((c) => workspace.append(c.el))

  window.chartConfigs = chartConfigs
  window.charts = charts
})
