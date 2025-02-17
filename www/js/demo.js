const {
  AreaSeries,
  BarSeries,
  BaselineSeries,
  CandlestickSeries,
  HistogramSeries,
  LineSeries
} = LightweightCharts

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
  const container = document.getElementById('container')
  const chartOptions = {
    layout: {
      textColor: 'black',
      background: { type: 'solid', color: 'white' },
    },
    rightPriceScale: {
      mode: 1 // https://tradingview.github.io/lightweight-charts/docs/api/enums/PriceScaleMode
    },
    autoSize: true,
    width:  640, // fallback if autoSize fails
    height: 620
  };
  const chart = LightweightCharts.createChart(container, chartOptions)
  chart.timeScale().fitContent()

  // TODO: In the next iteration, all this config info needs to come from the server.
  // I want chart state on the server to be reflected on the client in realtime.
  const ohlc = chart.addSeries(CandlestickSeries, {
    upColor: '#26a69a', downColor: '#ef5350', borderVisible: false,
    wickUpColor: '#26a69a', wickDownColor: '#ef5350',
  });
  const sma50 = chart.addSeries(LineSeries, { color: "#E072A4", lineWidth: 2 })
  const sma200 = chart.addSeries(LineSeries, { color: "#3D3B8E", lineWidth: 5 })
  const series = {
    ohlc,
    sma50,
    sma200
  } // I put them in an object so I could look them up by name.
  await loadSeries(series, "/demo/latest")

  // WebSockets
  const wsProtocol = location.protocol == 'http:' ? 'ws' : 'wss'
  const wsUrl = `${wsProtocol}://${location.host}/demo-ws`
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
        s = series[msg.series]
        data = msg.data
        s.update(data)
        break
      case "add":
        // The server-side makes an add vs update distinction,
        // but I guess the client doesn't have to.
        console.log("add", msg) 
        s = series[msg.series]
        data = msg.data
        s.update(data)
        break
      case "reset":
        console.warn("reset")
        window.reset() // client-side data clearing
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

  window.ws = ws
  window.series = series
  window.reset = () => {
    series.ohlc.setData([])
    series.sma50.setData([])
    series.sma200.setData([])
  }

  const resetInput = document.getElementById('reset')
  resetInput.addEventListener('click', (ev) => {
    ws.send(JSON.stringify({ type: "reset" }))
  })
  const startInput = document.getElementById('start')
  startInput.addEventListener('click', (ev) => {
    ws.send(JSON.stringify({ type: "start" }))
  })
  const stopInput = document.getElementById('stop')
  stopInput.addEventListener('click', (ev) => {
    ws.send(JSON.stringify({ type: "stop" }))
  })
  console.log("What's next?")
})

