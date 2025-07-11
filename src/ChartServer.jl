module ChartServer
using Oxygen; @oxidise
using HTTP
using HTTP: WebSockets
using Mustache
using JSON3

using Rocket
using UUIDs
using Dates
using DataFrames
using DataStructures

using CryptoMarketData
using OnlineTechnicalIndicators
using TechnicalIndicatorCharts

using MarketData # data for demo purposes

include("websockets.jl")
include("pages.jl")

# aka the project root
const ROOT = dirname(dirname(@__FILE__))

# Setup a dictionary of rooms, and
# setup a default demo room.
"""
`ROOMS` is a Dict that maps Symbols to Sets of WebSockets.
The Symbols represent room names, and the WebSockets are the clients
who are currently in those rooms.

> I'm not sure if `Set` was the right container to put those `WebSocket`s in, but I wanted to enforce uniqueness.
"""
ROOMS = Dict{Symbol, Set{HTTP.WebSocket}}(:demo => Set{HTTP.WebSocket}())
include("rooms.jl") # room_join, room_broadcast

# every N seconds, filter out all the disconnected websockets
@repeat 30 "websocket cleanup" function()
    for key in eachindex(ROOMS)
        room = ROOMS[key]
        filter!(ws -> !ws.writeclosed, room)
    end
end

## Rocket setup
include("rocket.jl")

"""
This is a Ref that you can manipulate to change the rate at which `candle_observable` emits candles.

# Example

```julia-repl
julia> CS.INTERVAL
Base.RefValue{Millisecond}(Millisecond(100))

julia> CS.INTERVAL[] = Millisecond(2000) # slow it down to 1 candle every 2 seconds
2000 milliseconds

julia> CS.INTERVAL
Base.RefValue{Millisecond}(Millisecond(2000))
```
"""
INTERVAL = Ref(Millisecond(100))

"""
This observable takes data from `MarketData.AAPL`
and emits each row as a `TechnicalIndicatorCharts.Candle`
at a rate of one candle per `CS.INTERVAL`.
"""
candle_observable = make_timearrays_candles(AAPL, INTERVAL)

function make_aapl_chart()
    Chart(
        "AAPL", Week(1),
        indicators = [
            SMA{Float64}(period=50),          # Setup indicators
            SMA{Float64}(period=200),
        ],
        visuals = [
            Dict(
                :label_name => "SMA 50",      # Describe how to draw indicators
                :line_color => "#E072A4",
                :line_width => 2
            ),
            Dict(
                :label_name => "SMA 200",
                :line_color => "#3D3B8E",
                :line_width => 5
            )
        ]
    )
end

"""
`aapl_chart` is a `TechnicalIndicatorCharts.Chart` of the
`MarketData.AAPL` data aggregated into 1 week candles.  A weekly 50
SMA and 200 SMA are also calculated for this chart.
"""
aapl_chart = make_aapl_chart()

"""
`chart_subject` consumes `Candle`s for 1 market and feeds them to the `Chart`s it has been asked to manage.
It emits change notifications as tuples when a value has been updated or added to a chart in its care.
"""
chart_subject = ChartSubject(charts = Dict(:aapl1w => aapl_chart))

"""
`websocket_actor` consumes notifications from chart_subject in the form of tuples and sends updates
to client-side charts via websockets.
"""
websocket_actor = WebSocketActor(room=:demo)

# Hook up the rocket parts.
subscribe!(chart_subject, websocket_actor)
# t = @task subscribe!(candle_observable, chart_subject); schedule(t)
# stop(t)

"""
Reset the contents of `aapl_chart` and tell every connected client in the demo room
to reset their client-side charts.
"""
function reset()
    global aapl_chart = make_aapl_chart()
    chart_subject.charts[:aapl1w] = aapl_chart
    room_broadcast(:demo, """{ "type": "reset" }""")
end

demo_task = missing

function start()
    if !ismissing(demo_task)
        if istaskstarted(demo_task) && !istaskdone(demo_task)
            @warn :demo_task message="demo_task is already running."
            return
        end
    end
    global demo_task = @task subscribe!(candle_observable, chart_subject)
    schedule(ChartServer.demo_task)
end

function stop()
    if ismissing(demo_task)
        @warn :missing messgage="demo_task hasn't been set yet"
        return
    end
    schedule(demo_task, InterruptException(); error=true)
end

# static files (but using dynamic during development)
# https://oxygenframework.github.io/Oxygen.jl/stable/#Mounting-Dynamic-Files
dynamicfiles(joinpath(ROOT, "www", "css"), "css")
dynamicfiles(joinpath(ROOT, "www", "js"), "js")
staticfiles(joinpath(ROOT, "www", "images"), "images")

# routes
@get "/" function(req::HTTP.Request)
    Pages.home()
end

@websocket "/demo-ws" function(ws::HTTP.WebSocket)
    @info :connect id=ws.id
    # Make new connections a member of the :demo room.
    # This also gives code outside of this `for data in ws` loop access to websocket connections.
    room_join(:demo, ws)

    for data in ws
        try
            msg = JSON3.read(data)
            if msg.type == "id"
                @info :id id=ws.id
                WebSockets.send(ws, JSON3.write(Dict(:id => ws.id)))
            elseif msg.type == "reset"
                @warn :reset
                reset()
            elseif msg.type == "start"
                @warn :start
                start()
            elseif msg.type == "stop"
                @warn :stop
                stop()
            else
                WebSockets.send(ws, JSON3.write((;type="unknown", msg=msg)))
            end
        catch err
            @info :nonjson data err
            WebSockets.send(ws, "[echo] $(data)")
        end
    end
    # When the connection closes, the @repeat task up top will clean them out of ROOMS eventually.
    # Doing it immediately caused errors that I didn't understand.
end

render_demo = Mustache.load(joinpath(ROOT, "tmpl", "demo.html"))
@get "/demo" function(req::HTTP.Request)
    render_demo()
end

"""    lwc_series(df::DataFrame) :: Dict{Symbol,Vector}

Turn the contents of a DataFrame into a Dict of series that can hydrate a client-side lightweightchart.
"""
function lwc_series(df::DataFrame)
    s = Dict{Symbol,Vector}(:ohlc => [])
    others = Symbol.(setdiff(names(df), STANDARD_FIELDS))
    for k in others
        s[k] = []
    end
    for row in eachrow(df)
        ohlcv = (
            time = nanodate2unixseconds(NanoDate(row.ts)),
            open = row.o,
            high = row.h,
            low = row.l,
            close = row.c,
            volume = row.v
        )
        push!(s[:ohlc], ohlcv)
        for k in others
            if !ismissing(row[k])
                v = (
                    time = nanodate2unixseconds(NanoDate(row.ts)),
                    value = row[k]
                )
                push!(s[k], v)
            end
        end
    end
    s
end

# return the latest candles as JSON
@get "/demo/latest" function(req::HTTP.Request)
    json(lwc_series(aapl_chart.df))
end

include("demo2.jl")

render_demo2 = Mustache.load(joinpath(ROOT, "tmpl", "demo2.html"))
@get "/demo2" function(req::HTTP.Request)
    RENDER_FUNCTIONS["demo2.html"]()
end

@get "/demo2/charts" function(req::HTTP.Request)
    OrderedDict(k => config(chart)
         for (k, chart) in demo2_chart_subject.charts)
end

@get "/demo2/latest" function(req::HTTP.Request)
    json(Dict(name => lwc_series(chart.df) for (name, chart) in demo2_chart_subject.charts))
end

@get "/demo2/latest/{name}" function(req::HTTP.Request, name::String)
    @info :latest name
    chart = demo2_chart_subject.charts[Symbol(name)]
    json(lwc_series(chart.df))
end

@websocket "/demo2/ws" function(ws::HTTP.WebSocket)
    @info :connect id=ws.id
    room_join(:demo2, ws)

    for data in ws
        try
            msg = JSON3.read(data)
            if msg.type == "id"
                @info :id id=ws.id
                WebSockets.send(ws, JSON3.write(Dict(:id => ws.id)))
            elseif msg.type == "start"
                @warn :start
                demo2_start()
            elseif msg.type == "stop"
                @warn :stop
                demo2_stop()
            else
                WebSockets.send(ws, JSON3.write((;type="unknown", msg=msg)))
            end
        catch err
            @info :nonjson data err
            WebSockets.send(ws, "[echo] $(data)")
        end
    end
end

include("watcher.jl")

end
