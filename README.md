# chartserver.jl

- This is an exploration in feeding data to [Lightweight Charts](https://www.tradingview.com/lightweight-charts/) over a websocket.
  + I lowercased the project name to signal that this would never be registered.
  + It's purely for exploration, experimentation and learning.
- There is much I am unsure about, so I'm going to try a few things to see how they feel.

## Usage

```bash
julia --project
```

```julia-repl
julia> ]
(ChartServer) pkg> instantiate

(ChartServer) pkg> <backspace>

julia> include("chartserver.jl")
┌ Info: ChartServer
│   fyi = "You may now `start()` and `stop()` the server."
└   also = "ChartServer has been abbreviated to CS."

julia> start()  # start the server in a background task

julia> stop()   # stop the server
```

# Log

## [2025-01-02 Thu] - /demo
- This demo exists to:
  + help me become familiar with lightweight-charts [realtime update](https://tradingview.github.io/lightweight-charts/tutorials/demos/realtime-updates) capabilities;
  + refresh my memory on how to use websockets both on the client and the server;
  + get a dialogue going with LightweightCharts.jl developers about [realtime chart updates](https://github.com/bhftbootcamp/LightweightCharts.jl/issues/32).
- It hard codes an AAPL chart on the 1w timeframe with a 50 SMA and 200 SMA on both the server and client sides.
  + The data is from `MarketData.AAPL`.
  + The aggregation from 1d candles to 1w candles is done by [TechnicalIndicatorCharts.jl](https://github.com/g-gundam/TechnicalIndicatorCharts.jl).
  + [Rocket.jl](https://github.com/ReactiveBayes/Rocket.jl) is being used to manage some async tasks.

### http://localhost:8080/demo

[Demo Video](https://files.catbox.moe/xhcupx.webm)

- Hit **Start** to watch it go.
- If you want to see it again, hit **Reset** and then **Start**.

If it's too slow, change `CS.INTERVAL[]` in the REPL like this:

```julia-repl
julia> CS.INTERVAL[] = Millisecond(5) # small intervals are faster
```

### Hacking

```julia-repl
julia> CS.ROOMS
Dict{Symbol, Set{WebSocket}} with 1 entry:
  :demo => Set()

# Send a JSON message to every connected client in the :demo room.
julia> CS.room_broadcast(:demo, """{ "type": "demo", "x": 5, "y": 9 }""")
1-element Vector{Int64}:
 38

# Revise doesn't notice template changes, so this is my workaround.
julia> CS.render_demo = Mustache.load(joinpath(CS.ROOT, "tmpl", "demo.html"))
```


## [2024-12-29 Sun] - The Initial Premise
- I have a `Chart` struct from [TechnicalIndicatorCharts.jl](https://github.com/g-gundam/TechnicalIndicatorCharts.jl) that can be continually updated.
- The initial goal will be to send the data contained in any given chart to any subscribed web clients via websockets.
- Any change to a chart instance should be automatically broadcast to any subscribed clients.
- Let's just start with that.
