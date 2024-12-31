# chartserver.jl

- This is an exploration in feeding data to [Lightweight Charts](https://www.tradingview.com/lightweight-charts/) over a websocket.
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

julia> start()  # start the server in a background task

julia> stop()   # stop the server
```

# Log

## [2024-12-29 Sun] - The Initial Premise
- I have a `Chart` struct from [TechnicalIndicatorCharts.jl](https://github.com/g-gundam/TechnicalIndicatorCharts.jl) that can be continually updated.
- The initial goal will be to send the data contained in any given chart to any subscribed web clients via websockets.
- Any change to a chart instance should be automatically broadcast to any subscribed clients.
- Let's just start with that.
