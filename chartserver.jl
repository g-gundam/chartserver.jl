using Revise
using Oxygen
import ChartServer as CS

# for REPL use
using Dates
using OnlineTechnicalIndicators
using TechnicalIndicatorCharts
using Mustache
using JSON3
using Rocket

global __T__

# INFO: It passes whatever kwargs you give it to ChartServer.serve.  It just adds :revise=>:eager by default.
function start(;kwargs...)
    defaults = Dict{Symbol,Any}(:revise => :eager)
    newkwargs = merge(defaults, kwargs)
    Main.__T__ = @task CS.serve(;newkwargs...)
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
