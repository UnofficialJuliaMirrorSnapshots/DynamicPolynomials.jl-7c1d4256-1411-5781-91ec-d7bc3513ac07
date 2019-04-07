function multiplyexistingvar(v::Vector{PolyVar{C}}, x::PolyVar{C}, i::Int) where {C}
    updatez = z -> begin
        newz = copy(z)
        newz[i] += 1
        newz
    end
    # /!\ v not copied for efficiency, do not mess up with vars
    v, updatez
end
function insertvar(v::Vector{PolyVar{C}}, x::PolyVar{C}, i::Int) where {C}
    n = length(v)
    I = 1:i-1
    J = i:n
    K = J.+1
    w = Vector{PolyVar{C}}(undef, n+1)
    w[I] = v[I]
    w[i] = x
    w[K] = v[J]
    updatez = z -> begin
        newz = Vector{Int}(undef, n+1)
        newz[I] = z[I]
        newz[i] = 1
        newz[K] = z[J]
        newz
    end
    w, updatez
end

include("cmult.jl")
include("ncmult.jl")

MP.multconstant(α, x::Monomial)   = Term(α, x)
MP.mapcoefficientsnz(f::Function, p::Polynomial) = Polynomial(f.(p.a), p.x)

# I do not want to cast x to TermContainer because that would force the promotion of eltype(q) with Int
function Base.:(*)(x::DMonomialLike, p::Polynomial)
    # /!\ No copy of a is done
    Polynomial(p.a, x*p.x)
end
function Base.:(*)(x::DMonomialLike{false}, p::Polynomial)
    # /!\ No copy of a is done
    # Order may change, e.g. y * (x + y) = y^2 + yx
    Polynomial(monovec(p.a, [x*m for m in p.x])...)
end
function Base.:(*)(p::Polynomial, x::DMonomialLike)
    # /!\ No copy of a is done
    Polynomial(p.a, p.x*x)
end

function _term_poly_mult(t::Term{C, S}, p::Polynomial{C, T}, op::Function) where {C, S, T}
    U = Base.promote_op(op, S, T)
    if iszero(t)
        zero(Polynomial{C, U})
    else
        n = nterms(p)
        allvars, maps = mergevars([t.x.vars, p.x.vars])
        nv = length(allvars)
        # Necessary to annotate the type in case it is empty
        Z = Vector{Int}[zeros(Int, nv) for i in 1:n]
        for i in 1:n
            Z[i][maps[1]] = t.x.z
            Z[i][maps[2]] += p.x.Z[i]
        end
        Polynomial(op.(t.α, p.a), MonomialVector(allvars, Z))
    end
end
Base.:(*)(p::Polynomial, t::Term) = _term_poly_mult(t, p, (α, β) -> β * α)
Base.:(*)(t::Term, p::Polynomial) = _term_poly_mult(t, p, *)
_sumprod(a, b) = a * b + a * b
function Base.:(*)(p::Polynomial{C, S}, q::Polynomial{C, T}) where {C, S, T}
    U = Base.promote_op(_sumprod, S, T)
    if iszero(p) || iszero(q)
        zero(Polynomial{C, U})
    else
        samevars = _vars(p) == _vars(q)
        if samevars
            allvars = _vars(p)
        else
            allvars, maps = mergevars([_vars(p), _vars(q)])
        end
        N = length(p)*length(q)
        Z = Vector{Vector{Int}}(undef, N)
        a = Vector{U}(undef, N)
        i = 0
        for u in p
            for v in q
                if samevars
                    z = u.x.z + v.x.z
                else
                    z = zeros(Int, length(allvars))
                    z[maps[1]] += u.x.z
                    z[maps[2]] += v.x.z
                end
                i += 1
                Z[i] = z
                a[i] = u.α * v.α
            end
        end
        polynomialclean(allvars, a, Z)
    end
end
