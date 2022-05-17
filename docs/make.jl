using Documenter, LifeContingencies

makedocs(;
    modules=[LifeContingencies],
    format=Documenter.HTML(;
    prettyurls=get(ENV, "CI", "false") == "true",
    canonical="https://JuliaActuary.github.io/Yields.jl",
    assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "API Reference" => "api.md",
    ],
    repo="https://github.com/JuliaActuary/LifeContingencies.jl/blob/{commit}{path}#L{line}",
    sitename="LifeContingencies.jl",
    authors="Alec Loudenback <alecloudenback@gmail.com> and contributors",
)

deploydocs(;
    repo="github.com/JuliaActuary/LifeContingencies.jl",
)