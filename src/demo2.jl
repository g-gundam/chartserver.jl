using HTTP
using HTTP: WebSocket, WebSockets
using URIs
using Visor
using Base.Threads # @spawn
using CryptoMarketData
using TechnicalIndicatorCharts
using TechnicalIndicatorCharts: Chart

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
    global bitstamp_ws_session = CryptoMarketData.subscribe(bitstamp_ws_uri)
end

# XXX: Translate from LWC.jl to lwc.js key names
function translate(opts)
    d = Dict()
    translation = Dict(
        :line_color => :color,
        :line_width => :width
    )
    for (k, v) in opts
        if haskey(translation, k)
            push!(d, translation[k] => v)
        else
            push!(d, k => v)
        end
    end
    return d
end

# INFO: This will be moved into TechnicalIndicatorCharts once I feel good about the function signature.
function config(ema::EMA, opts)
    name = TechnicalIndicatorCharts.indicator_fields(ema)[1]
    defaults = Dict(
        :_type => "line",
        :color => "#000"
    )
    final = merge(defaults, translate(opts))
    return name => final
end

# INFO: This will be moved into TechnicalIndicatorCharts once I feel good about the function signature.
function config(chart::Chart)
    series = [
        :ohlc => Dict(
            :_type => "ohlc",
            :upColor => "#26a69a",
            :downColor => "#ef5350",
            :wickUpColor => "#26a69a",
            :wickDownColor => "#ef5350",
            :borderVisible => false
        )
    ]
    for (i, indicator) in enumerate(chart.indicators)
        @info i
        visual = chart.visuals[i]
        push!(series, config(indicator, visual))
    end
    return Dict(
        :layout => Dict(
            :textColor => "black",
            :background => Dict(
                :type => "solid",
                :color => "white",
            )
        ),
        :rightPriceScale => Dict(
            :mode => 1
        ),
        :autoSize => true,
        :width => 640,
        :height => 620,
        :_series => Dict(series)
    )
end

#=
using CryptoMarketData
using Base.Threads

CS.bitstamp_ws_session = CryptoMarketData.subscribe(CS.bitstamp_ws_uri)
s = CS.bitstamp_ws_session

btcusd_subscribe = Dict(:event => "bts:subscribe", :data => Dict(:channel => "live_trades_btcusd"))
put!(s.commands, JSON3.write(btcusd_subscribe))

t = @spawn while true
    msg = take!(s.messages)
    m = JSON3.read(msg)
    ts = unix2datetime(parse(Int64, m[:data][:timestamp]))
    price = convert(Float64, m[:data][:price])
    Rocket.on_next!(CS.demo2_chart_subject, (ts, price))
end

=#
