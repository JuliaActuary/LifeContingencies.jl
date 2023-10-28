using Documenter, LifeContingencies

makedocs(;
    modules=[LifeContingencies],
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        assets=String[]
    ),
    pages=[
        "Home" => "index.md",
        "API Reference" => "api.md",
    ],
    repo=Remotes.GitHub("JuliaActuary", "LifeContingencies.jl"),
    sitename="LifeContingencies.jl",
    authors="Alec Loudenback <alecloudenback@gmail.com> and contributors"
)

deploydocs(;
    repo="github.com/JuliaActuary/LifeContingencies.jl"
)