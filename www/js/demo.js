document.addEventListener('DOMContentLoaded', () => {
  const container = document.getElementById('container')
  const chartOptions = {
    layout: {
      textColor: 'black',
      background: { type: 'solid', color: 'white' },
    },
    autoSize: true,
    width: 640, // fallback if autoSize fails
    height: 480
  };
  const chart = LightweightCharts.createChart(container, chartOptions)

  console.log("What's next?")
})
