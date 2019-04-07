# In Base/intfuncs.jl, x^p returns zero(x) when p == 0
# Since one(PolyVar) and one(Monomial) do not return
# a PolyVar and a Monomial, this results in type instability
# Defining the specific methods solve this problem and also make
# them a lot faster
Base.:(^)(x::PolyVar{C}, i::Int) where {C} = Monomial{C}([x], [i])
Base.:(^)(x::Monomial{true}, i::Int) = Monomial{true}(x.vars, i*x.z)

myminivect(x::T, y::T) where {T} = [x, y]
function myminivect(x::S, y::T) where {S,T}
    U = promote_type(S, T)
    [U(x), U(y)]
end

Base.:(+)(x::DMonomialLike, y::DMonomialLike) = Term(x) + Term(y)
Base.:(-)(x::DMonomialLike, y::DMonomialLike) = Term(x) - Term(y)

_getindex(p::Polynomial, i) = p[i]
_getindex(t::Term, i) = t
function plusorminus(p::TermPoly{C, S}, q::TermPoly{C, T}, op) where {C, S, T}
    varsvec = [_vars(p), _vars(q)]
    allvars, maps = mergevars(varsvec)
    nvars = length(allvars)
    U = Base.promote_op(op, S, T)
    a = Vector{U}()
    Z = Vector{Vector{Int}}()
    i = j = 1
    while i <= nterms(p) || j <= nterms(q)
        z = zeros(Int, nvars)
        if j > nterms(q) || (i <= nterms(p) && _getindex(p, i).x > _getindex(q, j).x)
            t = _getindex(p, i)
            z[maps[1]] = t.x.z
            α = convert(U, t.α)
            i += 1
        elseif i > nterms(p) || _getindex(q, j).x > _getindex(p, i).x
            t = _getindex(q, j)
            z[maps[2]] = t.x.z
            α = convert(U, op(t.α))
            j += 1
        else
            t = _getindex(p, i)
            z[maps[1]] = t.x.z
            s = _getindex(q, j)
            α = op(t.α, s.α)
            i += 1
            j += 1
        end
        push!(a, α)
        push!(Z, z)
    end

    Polynomial(a, MonomialVector{C}(allvars, Z))
end


Base.:(+)(x::TermPoly{C}, y::TermPoly{C}) where C = plusorminus(x, y, +)
Base.:(-)(x::TermPoly{C}, y::TermPoly{C}) where C = plusorminus(x, y, -)
Base.:(+)(x::TermPoly{C}, y::Union{Monomial,PolyVar}) where C = x + Term{C}(y)
Base.:(+)(x::Union{Monomial,PolyVar}, y::TermPoly{C}) where C = Term{C}(x) + y

Base.:(-)(x::TermPoly{T}, y::DMonomialLike) where T = x - Term{T}(y)
Base.:(-)(x::DMonomialLike, y::TermPoly{T}) where T = Term{T}(x) - y

Base.:(-)(p::Polynomial) = Polynomial(-p.a, p.x)

include("mult.jl")
