using Rocket
using TechnicalIndicatorCharts
using NanoDates

"""    make_timearrays_candles(ta::TimeArray, interval::Base.RefValue) :: FunctionObservable

Return a FunctionObservable that will emit one candle from `ta` at the given `interval`.

# Example:

```julia-repl
julia> interval = Ref(Millisecond(100))
Base.RefValue{Millisecond}(Millisecond(100))

julia> candle_observable = make_timearrays_candles(MarketData.AAPL, interval)
FunctionObservable(Candle)

julia> interval[] = Millisecond(2000) # Change the emission rate while it's going.
2000 milliseconds
```
"""
function make_timearrays_candles(ta::TimeArray, interval::Base.RefValue) # TODO: define type for interval more precisely
    Rocket.make(Candle) do actor
        for row in ta
            (date, vv) = row
            ts = DateTime(date)
            (o, h, l, c, v) = vv
            candle = Candle(;ts, o, h, l, c, v)
            next!(actor, candle)
            sleep(interval[])
        end
        complete!(actor)
    end
end

"""    bitstamp_candles()

Return an observable that emits candles from Bitstamp's WebSocket API.
"""
function bitstamp_candles()
    # Should I return more than one thing?
    # Maybe the websocket connection would be good to have.
    # I think I need to play with Visor.jl before I go any further.
    # Let's bake reliability into this from the beginning.
end



# The purpose of a ChartSubject is to feed candles to the Chart structs it has been asked to manage.
# These candles should all come from one market.
#
# consumes: Candle
# emits:    Tuple{Symbol, Symbol, Candle}
#           Tuple{Symbol, Symbol, String, DateTime, Float64}
#
# Symbol 1 = chart name
# Symbol 2 = :update or :add
# String 3 = field name for indicator (like :sma50)
# The rest is new data for the client-side charts.
@kwdef mutable struct ChartSubject <: Rocket.AbstractSubject{Any}
    charts::Dict{Symbol,Chart}
    subscribers::Vector = []
end

function Rocket.on_subscribe!(subject::ChartSubject, actor)
    push!(subject.subscribers, actor)
    return voidTeardown
end

const STANDARD_FIELDS = Set(["ts", "o", "h", "l", "c", "v"])

function handle_complete_candle(complete_candle, subject, c, k, v)
    if !isnothing(complete_candle)
        # This is the :add block.
        for s in subject.subscribers
            next!(s, (k, :add, complete_candle))
            # Also send everything that is not OHLCV.
            for field in setdiff(names(v.df), STANDARD_FIELDS)
                # INFO: Currently sending one field at a time, but it could be batched.
                value = v.df[end, field]
                ts = v.df[end, :ts]
                if !ismissing(value)
                    next!(s, (k, :add, field, ts, value))
                end
            end
        end
    else
        # This is the :update block.
        # Only candles can do updates in this system.
        # Indicators only change on candle close.
        for s in subject.subscribers
            current_candle = subject.charts[k].candle
            next!(s, (k, :update, current_candle))
        end
    end
end

# This is for exchanges that only give me a timestamp and a price over websockets.
function Rocket.on_next!(subject::ChartSubject, t::Tuple{DateTime, Float64})
    (ts,  price) = t
    for (k, v) in subject.charts
        complete_candle = TechnicalIndicatorCharts.update!(v, ts, price)
        handle_complete_candle(complete_candle, subject, c, k, v)
        yield()
    end
end

# This is for exchanges that give me an unfinished 1m candle over websockets
function Rocket.on_next!(subject::ChartSubject, c::Candle)
    for (k, v) in subject.charts
        complete_candle = TechnicalIndicatorCharts.update!(v, c)
        handle_complete_candle(complete_candle, subject, c, k, v)
        yield()
    end
end

# TODO: Make the room to broadcast to a struct member
@kwdef mutable struct WebSocketActor <: NextActor{Any}
    websockets::Vector = []
end

function to_lwc_candle(c::Candle)
    (
        time=nanodate2unixseconds(NanoDate(c.ts)),
        open=c.o,
        high=c.h,
        low=c.l,
        close=c.c,
        volume=c.v
    )
end

function Rocket.on_next!(actor::WebSocketActor, c::Tuple{Symbol,Symbol,Candle})
    (chart, action, candle) = c
    msg = (
        type=action,
        series="ohlc",
        data=to_lwc_candle(candle)
    )
    room_broadcast(:demo, JSON3.write(msg))
end

function Rocket.on_next!(actor::WebSocketActor, v::Tuple{Symbol,Symbol,String,DateTime,Float64})
    (chart, action, series, ts, value) = v
    msg = (
        type=action,
        series=series,
        data=(
            time=nanodate2unixseconds(NanoDate(ts)),
            value=value
        )
    )
    room_broadcast(:demo, JSON3.write(msg))
end

#=
PREP:
restart julia repl.
switch emacs to "*julia chartserver*" buffer
clear js console
=#

#=
RECORD:
hit record on peek.
in emacs, include("chartserver.jl")
move the mouse while it's compiling.
in emacs, start()
in browser, reload tab
in emacs, t = @task subscribe!(CS.candle_observer, CS.chart_subject); schedule(t)
in emacs, CS.INTERVAL[] = Millisecond(5)
in emacs, CS.INTERVAL[] = Millisecond(1)
stop recording when candles are finished

=#
