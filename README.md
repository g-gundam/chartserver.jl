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

## http://localhost:8080/

## Hacking

```julia-repl
julia> CS.ROOMS
Dict{Symbol, Set{WebSocket}} with 1 entry:
  :demo => Set()

# Send a JSON message to every connected client in the :demo room.
julia> CS.room_broadcast(:demo, """{ "type": "demo", "x": 5, "y": 9 }""")
1-element Vector{Int64}:
 38

# Revise doesn't notice template changes, so this is one workaround.
julia> CS.render_demo = Mustache.load(joinpath(CS.ROOT, "tmpl", "demo.html"))
```

# Log

## [2025-01-01 Wed] - /demo
- This first demo makes a lot of assumptions.
- The server side chart is data from MarketData.AAPL, but its 1d candles are aggregated into 1w candles.
- A 50 SMA and 200 SMA were also added.
- The client-side chart hard-codes those assumptions.

## [2024-12-29 Sun] - The Initial Premise
- I have a `Chart` struct from [TechnicalIndicatorCharts.jl](https://github.com/g-gundam/TechnicalIndicatorCharts.jl) that can be continually updated.
- The initial goal will be to send the data contained in any given chart to any subscribed web clients via websockets.
- Any change to a chart instance should be automatically broadcast to any subscribed clients.
- Let's just start with that.
