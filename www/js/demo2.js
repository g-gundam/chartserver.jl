// Goals
// - dynamic chart construction based on server-side chart config
// - realtime data consumption

// v4-to-v5: assign the various series types to consts
const {
  AreaSeries,
  BarSeries,
  BaselineSeries,
  CandlestickSeries,
  HistogramSeries,
  LineSeries
} = LightweightCharts

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
      series[k] = chart.addSeries(CandlestickSeries, seriesConfig)
      break;
    case "line":
      series[k] = chart.addSeries(LineSeries, seriesConfig)
      break;
    }
  })
  return { el, chart, series }
}

/**
 * Hydrate a lightweight chart by loading JSON data from the given URL.
 */
async function loadSeries(series, url) {
  let res = await fetch(url)
  let json = await res.json()
  for (k in json) {
    series[k].setData(json[k])
  }
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

  // load existing series data
  for await (const name of Object.keys(charts)) {
    await loadSeries(charts[name].series, `/demo2/latest/${name}`)
  }

  // setup resize handlers
  window.addEventListener('resize', () => {
    Object.keys(charts).forEach((name) => {
      const el = charts[name].el
      const ch = charts[name].chart
      // TODO: Revisit this.
      // For this to work, I have to disable autoSize on the chart.
      console.log(`[resize] width: ${el.offsetWidth}, height: ${el.offsetHeight}, win.width: ${window.innerWidth}, win.height: ${window.innerHeight}`)
      const width = window.innerWidth - 12
      const height = window.innerHeight / 2
      ch.resize(width, height, true)
    })
  })

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
      case "update":
        console.log("update", msg)
        s = charts[msg.chart].series[msg.series]
        data = msg.data
        s.update(data)
        break
      case "add":
        // The server-side makes an add vs update distinction,
        // but I guess the client doesn't have to.
        console.log("add", msg) 
        s = charts[msg.chart].series[msg.series]
        data = msg.data
        s.update(data)
        break
      default:
        console.log("default", msg)
        break
      }
    }
    catch (err) {
      console.log("non-json", msg)
    }
  }

  const startInput = document.getElementById('start')
  startInput.addEventListener('click', (ev) => {
    ws.send(JSON.stringify({ type: "start" }))
  })

  window.ws = ws
  window.chartConfigs = chartConfigs
  window.charts = charts
})
