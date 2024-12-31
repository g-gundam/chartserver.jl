using Rocket

function make_timearrays_candles(ta::TimeArray, interval::Base.RefValue{Dates.Period})
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

# consumes: Candle
# emits:    Tuple{Symbol, Symbol, Candle}
#           Tuple{Symbol, Symbol, Float64}
#
# Symbol 1 = chart name
# Symbol 2 = :update or :add
# The rest is new data for the client-side charts.
@kwdef mutable struct ChartSubject <: Rocket.AbstractSubject{Any}
    charts::Dict{Symbol,Chart}
    subscribers::Vector = []
end

function Rocket.on_subscribe!(subject::ChartSubject, actor)
    push!(subject.subscribers, actor)
    return voidTeardown
end

function Rocket.on_next!(subject::ChartSubject, c::Candle)
    for (k, v) in subject.charts
        complete_candle = TechnicalIndicatorCharts.update!(v, c)
        if !isnothing(complete_candle)
            # This is the :add block.
            for s in subject.subscribers
                next!(s, (k, :add, complete_candle))
                # TODO: Also send everything that is not OHLCV.
                #next!(s, (k, :add, all-non-ohlcv-fields ))
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
        yield()
    end
end