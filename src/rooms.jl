"""    room_broadcast(name::Symbol, message)

Send a message to every member of a room.
"""
function room_broadcast(name::Symbol, message)
    room = ROOMS[name]
    writable_sockets = filter(ws -> ws.writeclosed == false, values(room))
    WebSockets.send.(writable_sockets, message)
end

"""    room_join(name::Symbol, ws::HTTP.WebSocket)

Join a room, creating the room if it doesn't exist.
"""
function room_join(name::Symbol, ws::HTTP.WebSocket)
    if haskey(ROOMS, name)
        push!(ROOMS[name], ws)
    else
        ROOMS[name] = Set{HTTP.WebSocket}([ws])
    end
end

