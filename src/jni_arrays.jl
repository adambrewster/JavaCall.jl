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

Base.length(a::JavaArray) = GetArrayLength(penv, a.ptr)
Base.endof(a::JavaArray) = length(a)
Base.linearindexing{T}(::Type{JavaArray{T}}) = Base.LinearFast()
Base.size(a::JavaArray) = (length(a),)
Base.convert(::Type{JValue}, x::JavaArray) = convert(JValue, x.ptr)
Base.similar{T}(a::JavaArray, ::Type{T}, dim::NTuple{1,Int}) = jnewarray(T, dim[1])

function jnewarray{T}(::Type{JavaObject{T}}, siz::Int)
    array = NewObjectArray(penv, siz, metaclass(T).ptr, C_NULL)
    if array == C_NULL geterror(true) end
    JavaArray(JavaObject{T}, array)
end

function Base.getindex{T}(a::JavaArray{JavaObject{T}}, i::Int)
    x = GetObjectArrayElement(penv, a.ptr, i-1)
    geterror()
    return x
end
Base.getindex{T}(a::JavaArray{JavaObject{T}}, i::AbstractVector{Int}) = JavaObject{T}[a[ii] for ii in i]

function Base.setindex!{T}(a::JavaArray{JavaObject{T}}, v::JavaObject{T}, i::Int)
    x = SetObjectArrayElement(penv, a.ptr, i-1, v)
    geterror(true)
    return v
end

function Base.setindex!{T}(a::JavaArray{JavaObject{T}}, v::JavaObject{T}, i::AbstractVector{Int})
    n = 1
    for ii in i
        a[ii] = v
        n += 1
    end
end

function Base.setindex!{T}(a::JavaArray{JavaObject{T}}, v::AbstractArray{JavaObject{T},1}, i::AbstractVector{Int})
    n = 1
    for ii in i
        a[ii] = v[n]
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
        x = Array($T, length(i))
        $(get)(penv, a.ptr, start(i)-1, length(i), x)
        geterror()
        return x
    end

    @eval function Base.setindex!(a::JavaArray{$T}, v::Array{$T}, i::UnitRange)
        $(set)(penv, a.ptr, start(i)-1, length(i), v)
        return v
    end
end
