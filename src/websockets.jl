module WS

using HTTP
using HTTP: WebSockets
using URIs

# This is used to contain WebSocket sessions and interact with them.
# It's generic and can be used for any exchange.
@kwdef mutable struct Session
    url::URI
    commands::Union{Channel, Missing}
    messages::Union{Channel, Missing}
    ws::Union{HTTP.WebSocket, Missing}
    task::Union{Task, Missing}
end

"""
    connect(url::String) :: WS.Session

This is a convenience method that accepts URLs as strings.
"""
function connect(url::AbstractString)
    connect(URI(uri))
end

"""
    connect(uri::URI) :: WS.Session

This is the general version of websocket subscription that the other exchange-specific
versions of subscribe are built on.  It connects to the given uri and returns a struct
that contains two Channels that can be used to interact with the WebSocket.

# Example

```julia-repl
julia> using URIs, JSON3

julia> s = connect(URI("wss://ws.bitstamp.net"))
CryptoMarketData.Session(URI("wss://ws.bitstamp.net"), missing, missing, missing, Task (runnable) @0x00007970dac63d00)

julia> btcusd_subscribe = Dict(:event => "bts:subscribe", :data => Dict(:channel => "live_trades_btcusd"))
Dict{Symbol, Any} with 2 entries:
  :event => "bts:subscribe"
  :data  => Dict(:channel=>"live_trades_btcusd")

julia> put!(s.commands, JSON3.write(btcusd_subscribe))
"{\"event\":\"bts:subscribe\",\"data\":{\"channel\":\"live_trades_btcusd\"}}"

julia> s.messages
Channel{Any}(32) (2 items available)

julia> take!(s.messages)
"{\"event\":\"bts:subscription_succeeded\",\"channel\":\"live_trades_btcusd\",\"data\":{}}"

julia> JSON3.read(take!(s.messages))
JSON3.Object{Base.CodeUnits{UInt8, String}, Vector{UInt64}} with 3 entries:
  :data    => {…
  :channel => "live_trades_btcusd"
  :event   => "trade"
```
"""
function connect(uri::URI)
    session = Session(uri, missing, missing, missing, missing)
    handler = function (ws)
        session.ws = ws
        session.commands = Channel(32)
        session.messages = Channel(32) do ch
            while true
                msg = WebSockets.receive(ws)
                put!(ch, msg)
            end
        end
        try
            while true
                command = take!(session.commands)
                if command == :disconnect
                    break
                end
                WebSockets.send(session.ws, command)
            end
        catch e
            @warn "exception, restart"
            sleep(0.10) # TODO: debounce the websocket reconnection
            session.task = Threads.@spawn WebSockets.open(handler, uri)
        end
    end
    session.task = Threads.@spawn WebSockets.open(handler, uri)
    return session
end

"""    disconnect(session::Session)

Close the websocket connection and stop the task that was handling the connection.
"""
function disconnect(session::Session)
    put!(session.commands, :disconnect)
    WebSockets.close(session.ws)
    schedule(session.task, InterruptException(); error=true)
end

end
