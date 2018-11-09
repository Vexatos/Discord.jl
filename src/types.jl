# First millisecond of 2015.
const DISCORD_EPOCH = 1420070400000

# Discord's form of ID.
const Snowflake = UInt64

snowflake(s::Integer) = Snowflake(s)
snowflake(s::AbstractString) = parse(Snowflake, s)

# TODO: Put these in helpers?
snowflake2datetime(s::Snowflake) = unix2datetime(((s >> 22) + DISCORD_EPOCH) / 1000)
worker_id(s::Snowflake) = (s & 0x3E0000) >> 17
process_id(s::Snowflake) = (s & 0x1F000) >> 12
increment(s::Snowflake) = s & 0xFFF

# Discord sends both Unix and ISO timestamps.
datetime(s::Int) = unix2datetime(s / 1000)
datetime(s::AbstractString) = DateTime(replace(s, "+" => ".000+")[1:23], ISODateTimeFormat)

lowered(x::DateTime) = round(Int, datetime2unix(x))
lowered(x::Union{Integer, Bool}) = x
lowered(x::Vector) = lowered.(x)
lowered(x::Nothing) = nothing
lowered(x) = JSON.lower(x)

macro lower(T)
    if supertype(eval(T)) <: Enum{<:Integer}
        quote
            JSON.lower(x::$T) = Int(x)
        end
    else
        quote
            function JSON.lower(x::$T)
                d = Dict{String, Any}()

                for f in fieldnames($T)
                    v = getfield(x, f)
                    if !ismissing(v)
                        d[string(f)] = lowered(v)
                    end
                end

                return d
            end
        end
    end
end

macro merge(T)
    quote
        function Base.merge(a::$T, b::$T)
            vals = []

            for f in fieldnames($T)
                va = getfield(a, f)
                vb = getfield(b, f)
                push!(vals, ismissing(vb) ? va : vb)
            end

            return $T(vals...)
        end
        Base.merge(::Missing, x::$T) = x
        Base.merge(x::$T, ::Missing) = x
    end
end

field(k::String, ::Type{Any}) = :(d[$k])
field(k::String, ::Type{Snowflake}) = :(snowflake(d[$k]))
field(k::String, ::Type{DateTime}) = :(datetime(d[$k]))
field(k::String, ::Type{T}) where T = :($T(d[$k]))
field(k::String, ::Type{Vector{Snowflake}}) = :(snowflake.(d[$k]))
field(k::String, ::Type{Vector{DateTime}}) = :(datetime.(d[$k]))
field(k::String, ::Type{Vector{T}}) where T = :($T.(d[$k]))
function field(k::String, ::Type{Union{T, Missing}}) where T
    return :(haskey(d, $k) ? $(field(k, T)) : missing)
end
function field(k::String, ::Type{Union{T, Nothing}}) where T
    return :(d[$k] === nothing ? nothing : $(field(k, T)))
end
function field(k::String, ::Type{Union{T, Nothing, Missing}}) where T
    return :(haskey(d, $k) ? $(field(k, Union{T, Nothing})) : missing)
end

macro dict(T)
    TT = eval(T)
    args = map(f -> field(string(f), fieldtype(TT, f)), fieldnames(TT))

    quote
        function $(esc(T))(d::Dict{String, Any})
            $(esc(T))($(args...))
        end
    end
end

function doctype(s::String)
    s = replace(s, "UInt64" => "Snowflake")
    s = replace(s, "Int64" => "Int")
    s = replace(s, "Discord." => "")
    s = replace(s, "Dates." => "")
    m = match(r"Array{([^{}]+),1}", s)
    m === nothing || (s = replace(s, m.match => "Vector{$(m.captures[1])}"))
    m = match(r"Union{Missing, Nothing, (.+)}", s)
    m === nothing || return replace(s, m.match => "Union{$(m.captures[1]), Missing, Nothing}")
    m = match(r"Union{Missing, (.+)}", s)
    m === nothing || return replace(s, m.match => "Union{$(m.captures[1]), Missing}")
    m = match(r"Union{Nothing, (.+)}", s)
    m === nothing || return replace(s, m.match => "Union{$(m.captures[1]), Nothing}")
    return s
end

macro fielddoc(T)
    TT = eval(T)
    ns = collect(string.(fieldnames(TT)))
    width = maximum(length, ns)
    map!(n -> rpad(n, width), ns, ns)
    ts = collect(map(f -> string(fieldtype(TT, f)), fieldnames(TT)))
    map!(doctype, ts, ts)
    docs = join(map(t -> "$(t[1]) :: $(t[2])", zip(ns, ts)), "\n")

    quote
        doc = string(@doc $T)
        docstring = doc * "\n# Fields\n\n```\n" * $docs * "\n```\n"

        with_logger(NullLogger()) do
            @doc docstring $T
        end
    end
end

macro boilerplate(T, exs...)
    macros = map(e -> e.value, exs)

    quote
        @static if :docs in $macros
            @fielddoc $T
        end
        @static if :dict in $macros
            @dict $T
        end
        @static if :lower in $macros
            @lower $T
        end
        @static if :merge in $macros
            @merge $T
        end
    end
end

include(joinpath("types", "overwrite.jl"))
include(joinpath("types", "role.jl"))
include(joinpath("types", "guild_embed.jl"))
include(joinpath("types", "attachment.jl"))
include(joinpath("types", "voice_region.jl"))
include(joinpath("types", "activity.jl"))
include(joinpath("types", "embed.jl"))
include(joinpath("types", "user.jl"))
include(joinpath("types", "ban.jl"))
include(joinpath("types", "integration.jl"))
include(joinpath("types", "connection.jl"))
include(joinpath("types", "emoji.jl"))
include(joinpath("types", "reaction.jl"))
include(joinpath("types", "presence.jl"))
include(joinpath("types", "channel.jl"))
include(joinpath("types", "webhook.jl"))
include(joinpath("types", "invite_metadata.jl"))
include(joinpath("types", "member.jl"))
include(joinpath("types", "voice_state.jl"))
include(joinpath("types", "message.jl"))
include(joinpath("types", "guild.jl"))
include(joinpath("types", "invite.jl"))
include(joinpath("types", "audit_log.jl"))
