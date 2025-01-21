using HTTP
using HTTP: WebSocket, WebSockets
using URIs
using Visor
using Base.Threads # @spawn
using CryptoMarketData
using TechnicalIndicatorCharts
using TechnicalIndicatorCharts: Chart, abbrev
using DataStructures

# room init just in case they haven't loaded /demo2 yet
if !haskey(ROOMS, :demo2)
    ROOMS[:demo2] = Set{HTTP.WebSocket}()
end

# BTCUSD1M
bitstamp_chart_btcusd1m = Chart(
    "BTCUSD", Minute(1),
    indicators=[EMA{Float64}(period=9), EMA{Float64}(period=12)],
    visuals=[
        Dict(:line_color => "#E9B872"),
        Dict(:line_color => "#6494AA")
    ]
)

# BTCUSD3M
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

demo2_chart_subject = ChartSubject(charts=OrderedDict(
    :btcusd1m => bitstamp_chart_btcusd1m,
    :btcusd3m => bitstamp_chart_btcusd3m
))

bitstamp_ws_uri = URI("wss://ws.bitstamp.net")
bitstamp_ws_session = nothing # CMD.subscribe(bitstamp_ws_uri)

demo2_websocket_actor = WebSocketActor(room=:demo2)

subscribe!(demo2_chart_subject, demo2_websocket_actor)

demo2_task = nothing

function bitstamp_ws_open()
    global bitstamp_ws_session = WS.connect(bitstamp_ws_uri)
end

function bitstamp_ws_subscribe()
    s = bitstamp_ws_session
    btcusd_subscribe = Dict(:event => "bts:subscribe", :data => Dict(:channel => "live_trades_btcusd"))
    put!(s.commands, JSON3.write(btcusd_subscribe))
    return JSON3.read(take!(s.messages)) # INFO: the first message back is a subscription confirmation and not price data.
end

function demo2_start()
    bitstamp_ws_open()
    tw = timedwait(5) do
        return !ismissing(bitstamp_ws_session.commands)
    end
    @info :subscribe tw bitstamp_ws_subscribe()
    s = bitstamp_ws_session
    global demo2_task = @spawn while true
        msg = take!(s.messages)
        m = JSON3.read(msg)
        ts = unix2datetime(parse(Int64, m[:data][:timestamp]))
        price = convert(Float64, m[:data][:price])
        Rocket.on_next!(demo2_chart_subject, (ts, price))
    end
end

# TODO: implement some kind of shutdown for websockets
function demo2_stop()
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
        :timeScale => Dict(
            :timeVisible => true,
        ),
        :localization => Dict(
            :dateFormat => "yyyy-MM-dd",
        ),
        :watermark => Dict(
            :visible => true,
            :fontSize => 64,
            :horzAlign => "center",
            :vertAlign => "center",
            :color => "rgba(20,20,20,0.1)",
            :text => "$(chart.name) $(abbrev(chart.tf))",
        ),
        :autoSize => true,
        :width => 640,
        :height => 220,
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
