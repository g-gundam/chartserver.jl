using HTTP
using HTTP: WebSocket, WebSockets
using URIs
using Visor
using Base.Threads # @spawn
using CryptoMarketData

bitstamp_chart_btcusd1m = Chart(
    "BTCUSD", Minute(1),
    indicators=[EMA{Float64}(period=9), EMA{Float64}(period=12)],
    visuals=[
        Dict(:line_color => "#E9B872"),
        Dict(:line_color => "#6494AA")
    ]
)

bitstamp_chart_btcusd3m = Chart(
    "BTCUSD", Minute(3),
    indicators=[EMA{Float64}(period=20)],
    visuals=[
        Dict(
            :line_color => "#A63D40",
            :line_width => 3
        )
    ]
)

demo2_chart_subject = ChartSubject(charts=Dict(
    :btcusd1m => bitstamp_chart_btcusd1m,
    :btcusd3m => bitstamp_chart_btcusd3m
))

bitstamp_ws_uri = URI("wss://ws.bitstamp.net")
bitstamp_ws_session = nothing # CMD.subscribe(bitstamp_ws_uri)

function bitstamp_ws_open()
    global bitstamp_ws_session = CryptoMarketData.subscribe(bitstamp_ws_url)
end
