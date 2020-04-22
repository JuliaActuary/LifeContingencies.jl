using Documenter, LifeContingencies

makedocs(;
    modules=[LifeContingencies],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/JuliaActuary/LifeContingencies.jl/blob/{commit}{path}#L{line}",
    sitename="LifeContingencies.jl",
    authors="Alec Loudenback",
)

deploydocs(;
    repo="github.com/JuliaActuary/LifeContingencies.jl",
)