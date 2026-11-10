# Test fixture for Dependabot's hex updater: a git dependency on a large repository (about 12 GiB),
# pinned to an older tag. With a cooldown, Dependabot reads the tag dates from a bare clone of it.
defmodule CooldownFixture.MixProject do
  use Mix.Project

  def project do
    [app: :cooldown_fixture, version: "0.1.0", elixir: "~> 1.15", deps: deps()]
  end

  defp deps do
    [
      {:daisyui,
       github: "saadeghi/daisyui",
       tag: "v5.7.50",
       sparse: "packages/bundle",
       app: false,
       compile: false,
       depth: 1}
    ]
  end
end
