using FileWatching
using Base.Threads

RENDER_FUNCTIONS = Dict{AbstractString,Mustache.MustacheTokens}()
RENDER_FUNCTIONS["demo.html"] = render_demo
RENDER_FUNCTIONS["demo2.html"] = render_demo2

filewatching_task = nothing

function start_watcher()
    global filewatching_task = @spawn while true
        ev = FileWatching.watch_folder(joinpath(ROOT, "tmpl"))
        RENDER_FUNCTIONS[ev.first] = Mustache.load(joinpath(ROOT, "tmpl", ev.first))
    end
end
