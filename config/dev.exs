use Mix.Config

config :version_release,
  tag_prefix: "v",
  hex_publish: true,
  changelog: %{
    creation: :manual,
    replacements: [
      %{
        file: "README.md",
        patterns: [
          %{search: ~r/quarry, \"~> (.*)\"/, replace: "quarry, \"{{version}}\""}
        ]
      },
      %{
        file: "CHANGELOG.md",
        type: :changelog,
        patterns: [
          %{search: "Unreleased", replace: "{{version}}", type: :unreleased},
          %{search: "...HEAD", replace: "...{{tag_name}}", global: false},
          %{search: "ReleaseDate", replace: "{{date}}"},
          %{
            search: "<!-- next-header -->",
            replace: "<!-- next-header -->\n\n## [Unreleased] - ReleaseDate",
            global: false
          },
          %{
            search: "<!-- next-url -->",
            replace:
              "<!-- next-url -->\n[Unreleased]: https://github.com/enewbury/quarry/compare/{{tag_name}}...HEAD",
            global: false
          }
        ]
      }
    ]
  }
