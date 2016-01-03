type JavaArray{T} <: AbstractArray{T, 1}
    ptr::Ptr{Void}

    function JavaArray(ptr)
        j=new(ptr)
        finalizer(j, deleteref)
        return j
    end

    JavaArray(siz::Int) = jnewarray(T, siz)
end

JavaArray(T, ptr) = JavaArray{T}(ptr)

function deleteref(x::JavaArray)
    if x.ptr == C_NULL; return; end
    if (penv==C_NULL); return; end
    DeleteLocalRef(penv, x.ptr)
    x.ptr=C_NULL #Safety in case this function is called direcly, rather than at finalize
    return
end

Base.length(a::JavaArray) = a.ptr == C_NULL ? 0 : Int(GetArrayLength(penv, a.ptr))
Base.endof(a::JavaArray) = length(a)
Base.linearindexing{T}(::Type{JavaArray{T}}) = Base.LinearFast()
Base.size(a::JavaArray) = (length(a),)
Base.convert(::Type{JValue}, x::JavaArray) = convert(JValue, x.ptr)
Base.similar{T}(a::JavaArray, ::Type{T}, dim::NTuple{1,Int}) = jnewarray(T, dim[1])

signature{T}(::Type{JavaArray{T}}) = symbol("[", signature(T))
metaclass{T}(t::Type{JavaArray{T}}) = metaclass(signature(t))
metaclass{T}(a::JavaArray{T}) = metaclass(typeof(a))

typealias JRef Union{JavaObject,JavaArray}

function jnewarray{T<:JRef}(t::Type{T}, siz::Int)
    array = NewObjectArray(penv, siz, metaclass(t).ptr, C_NULL)
    if array == C_NULL geterror(true) end
    JavaArray(t, array)
end

function Base.getindex{T<:JRef}(a::JavaArray{T}, i::Int)
    if a.ptr == C_NULL error("NullPointerException") end
    x = GetObjectArrayElement(penv, a.ptr, i-1)
    if x == nothing geterror() end
    return T(x)
end
Base.getindex{T<:JRef}(a::JavaArray{T}, i::AbstractVector{Int}) = T[a[ii] for ii in i]

function Base.setindex!{T<:JRef}(a::JavaArray{T}, v::T, i::Int)
    if a.ptr == C_NULL error("NullPointerException") end
    SetObjectArrayElement(penv, a.ptr, i-1, v.ptr)
    geterror()
    return v
end

function Base.setindex!{T<:JRef}(a::JavaArray{T}, v::T, i::AbstractVector{Int})
    n = 1
    for ii in i
        a[ii] = v.ptr
        n += 1
    end
end

function Base.setindex!{T<:JRef}(a::JavaArray{T}, v::AbstractArray{T,1}, i::AbstractVector{Int})
    n = 1
    for ii in i
        a[ii] = v[n].ptr
        n += 1
    end
end

Base.getindex{T<:jprimitive}(a::JavaArray{T}, i::Int) = getindex(a, i:i)[1]
Base.setindex!{T<:jprimitive}(a::JavaArray{T}, v::Number, i::Int) = setindex!(a, T[v], i:i)

for t in ["Boolean", "Byte", "Char", "Short", "Int", "Long", "Float", "Double"]
    T = symbol("j", lowercase(t))
    new = symbol("New", t, "Array")
    get = symbol("Get", t, "ArrayRegion")
    set = symbol("Set", t, "ArrayRegion")

    @eval function jnewarray(::Type{$T}, siz::Int)
        array = $(new)(penv, siz)
        if array == C_NULL geterror(true) end
        JavaArray($T, array)
    end

    @eval function Base.getindex(a::JavaArray{$T}, i::UnitRange)
        if a.ptr == C_NULL error("NullPointerException") end
        x = Array($T, length(i))
        $(get)(penv, a.ptr, start(i)-1, length(i), x)
        geterror()
        return x
    end

    @eval function Base.setindex!(a::JavaArray{$T}, v::Array{$T}, i::UnitRange)
        if a.ptr == C_NULL error("NullPointerException") end
        $(set)(penv, a.ptr, start(i)-1, length(i), v)
        return v
    end
end
