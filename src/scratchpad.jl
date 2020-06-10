struct arraywrap
    v
end

Base.iterate(a::arraywrap,state=1) = state > length(a.v) ? nothing : (a.v[state],state + 1)

Base.IteratorSize(::arraywrap) = Base.HasLength()

Base.length(a::arraywrap) = length(a.v)