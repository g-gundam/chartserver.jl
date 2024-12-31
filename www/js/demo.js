document.addEventListener('DOMContentLoaded', () => {
  const container = document.getElementById('container')
  const chartOptions = {
    layout: {
      textColor: 'black',
      background: { type: 'solid', color: 'white' },
    },
    autoSize: true,
    width:  640, // fallback if autoSize fails
    height: 640
  };
  const chart = LightweightCharts.createChart(container, chartOptions)
  const candlestickSeries = chart.addCandlestickSeries({
    upColor: '#26a69a', downColor: '#ef5350', borderVisible: false,
    wickUpColor: '#26a69a', wickDownColor: '#ef5350',
  });

  const wsProtocol = location.protocol == 'http:' ? 'ws' : 'wss'
  const wsUrl = `${wsProtocol}://${location.host}/demo-ws`
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
        break
      case "add":
        console.log("add", msg)
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
