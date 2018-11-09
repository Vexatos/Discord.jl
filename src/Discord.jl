module Discord

using Base: Semaphore, acquire, release
using Base.CoreLogging
using Base.CoreLogging: Debug, Info, Warn, Error
using Base.Threads
using Base.Threads: AbstractLock
using Dates
using Distributed
using HTTP
using JSON
using OpenTrick
using Setfield
using TimeToLive

const DISCORD_JL_VERSION = v"0.1.0"
const API_VERSION = 6
const DISCORD_API = "https://discordapp.com/api"

const TTLDict = Dict{DataType, Union{Period, Nothing}}

function locked(f::Function, x::AbstractLock)
    lock(x)
    try f() finally unlock(x) end
end

function catchmsg(e::Exception)
    return sprint(showerror, e) * sprint(Base.show_backtrace, catch_backtrace())
end

include("types.jl")
include("events.jl")
include("state.jl")
include("limiter.jl")
include("client.jl")
include("gateway.jl")
include("rest.jl")
include("crud.jl")
include("commands.jl")
include("helpers.jl")
include("Defaults.jl")

end
