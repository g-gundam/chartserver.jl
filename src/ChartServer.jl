module ChartServer
using Oxygen; @oxidise
using HTTP
using HTTP: WebSockets
using Mustache

using Rocket
using UUIDs

using CryptoMarketData
using OnlineTechnicalIndicators
using TechnicalIndicatorCharts

using MarketData # data for demo purposes

# aka the project root
const ROOT = dirname(dirname(@__FILE__))

# Setup a dictionary of rooms, and
# setup a default demo room.
ROOMS = Dict{Symbol, Set{HTTP.WebSocket}}(:demo => Set{HTTP.WebSocket}())
include("rooms.jl") # room_join, room_broadcast

# every N seconds, filter out all the disconnected websockets
@repeat 30 "websocket cleanup" function()
    for key in eachindex(ROOMS)
        room = ROOMS[key]
        filter!(ws -> !ws.writeclosed, room)
    end
end

# static files (but using dynamic during development)
# https://oxygenframework.github.io/Oxygen.jl/stable/#Mounting-Dynamic-Files
dynamicfiles(joinpath(ROOT, "www", "css"), "css")
dynamicfiles(joinpath(ROOT, "www", "js"), "js")

# routes
@get "/" function(req::HTTP.Request)
    html("<a href=\"/demo\">demo</a>")
end

@websocket "/demo-ws" function(ws::HTTP.WebSocket)
    @info "demo-ws" message="connect" uuid=ws.id
    # make them a member of the :demo room on connect
    room_join(:demo, ws)
    # echo server for now
    # but what do we want this long-lived connection to do?
    for msg in ws
        WebSockets.send(ws, msg)
    end
    # When the connection closes, the @repeat task up top will clean them out of ROOMS eventually.
    # Doing it immediately caused errors that I didn't understand.
end

@get "/demo" function(req::HTTP.Request)
    """
    js to setup a chart
    js to load initial chart state via HTTP
    js to setup a websocket connection to get chart state updates
    """
end

end
