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

  const charts = Object.keys(chartConfigs).reduce((result, name) => {
    result[name] = createChart(chartConfigs[name])
    return result
  }, {})

  // append to #workspace
  const workspace = document.getElementById("workspace")
  Object.keys(charts).forEach((name) => workspace.append(charts[name].el))

  // WebSockets
  const wsProtocol = location.protocol == 'http:' ? 'ws' : 'wss'
  const wsUrl = `${wsProtocol}://${location.host}/demo2/ws`
  console.info(wsUrl)
  const ws = new WebSocket(wsUrl)
  ws.onopen = (ev) => {
    console.log('connected')
  }
  ws.onclose = (ev) => {
    console.log('disconnected')
  }
  ws.onmessage = (ev) => {
    let msg = ev.data
    try {
      msg = JSON.parse(ev.data)
      switch (msg.type) {
      default:
        console.log("default", msg)
        break
      }
    }
    catch (err) {
      console.log("non-json", msg)
    }
  }

  window.ws = ws
  window.chartConfigs = chartConfigs
  window.charts = charts
})
