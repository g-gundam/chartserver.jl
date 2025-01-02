document.addEventListener('DOMContentLoaded', () => {
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
    height: 640
  };
  const chart = LightweightCharts.createChart(container, chartOptions)
  chart.timeScale().fitContent()

  // TODO: In the next iteration, all this config info needs to come from the server.
  // I want chart state on the server to be reflected on the client in realtime.
  const ohlc = chart.addCandlestickSeries({
    upColor: '#26a69a', downColor: '#ef5350', borderVisible: false,
    wickUpColor: '#26a69a', wickDownColor: '#ef5350',
  });
  const sma50 = chart.addLineSeries({ color: "#E072A4", width: 2 })
  const sma200 = chart.addLineSeries({ color: "#3D3B8E", width: 5 })
  const series = {
    ohlc,
    sma50,
    sma200
  }

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
    let msg = event.data
    try {
      msg = JSON.parse(event.data)
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
  console.log("What's next?")
})
