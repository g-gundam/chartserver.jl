using Revise
using Oxygen
import ChartServer as CS

global __T__

function start()
    Main.__T__ = @task CS.serve(revise=:eager)
    schedule(Main.__T__)
end

function stop()
    schedule(Main.__T__, InterruptException, error=true);
end

# If run from the command line via:
#
#     julia --project chartserver.jl
#
# It will run this block.
if abspath(PROGRAM_FILE) == @__FILE__
    start()
    wait(Main.__T__)
end

# If you include this from the REPL via:
#
#    include("chartserver.jl")
#
# You get to `start()` and `stop()` the server.
@info(
    "ChartServer",
    fyi="You may now `start()` and `stop()` the server.",
    also="ChartServer has been abbreviated to CS."
)
