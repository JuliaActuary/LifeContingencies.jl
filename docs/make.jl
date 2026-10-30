using Documenter, LifeContingencies

DocMeta.setdocmeta!(LifeContingencies, :DocTestSetup, :(using LifeContingencies, MortalityTables); recursive=true)

makedocs(;
    modules=[LifeContingencies, LifeContingencies.Experimental],
    checkdocs=:exports,
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        edit_link="master",
        canonical="https://docs.juliaactuary.org/LifeContingencies/stable/",
        assets=String[]
    ),
    pages=[
        "Home" => "index.md",
        "Getting started" => "getting-started.md",
        "User guide" => [
            "Mortality and lives" => "mortality-and-lives.md",
            "Insurance and annuities" => "insurance-and-annuities.md",
            "Valuation and reserves" => "valuation-and-reserves.md",
            "Joint lives" => "joint-lives.md",
            "Curves and scenarios" => "curves-and-scenarios.md",
            "Actuarial notation" => "actuarial-notation.md",
        ],
        "Multi-state models" => [
            "Building multi-state models" => "multi-state-models.md",
            "LTC worked example" => "ltc.md",
        ],
        "Reference and upgrading" => [
            "Stable API" => "api.md",
            "Experimental API" => "experimental-api.md",
            "Migrating to 3.0" => "migration.md",
        ],
    ],
    repo=Remotes.GitHub("JuliaActuary", "LifeContingencies.jl"),
    sitename="LifeContingencies.jl",
    authors="Alec Loudenback <alecloudenback@gmail.com> and contributors"
)

deploydocs(;
    repo="github.com/JuliaActuary/LifeContingencies.jl",
    devbranch="master"
)
