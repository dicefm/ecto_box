defmodule EctoBox.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_box,
      version: "0.1.0",
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, ">= 3.0.0"},
      {:typed_ecto_schema, ">= 0.1.1"},
      {:ex_doc, "~> 0.1", only: [:dev, :test], runtime: false}
      # {:req, "~> 0.3.11", only: [:dev, :test]}
    ]
  end

  defp docs do
    [
      main: "Overview",
      extras: [
        "README.md": [title: "Overview", filename: "overview"],
        "ecto_box.livemd": [title: "Live Example", filename: "ecto_box.livemd"]
      ],
      before_closing_body_tag: fn
        :html ->
          """
          <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
          <script>mermaid.initialize({startOnLoad: true})</script>
          """

        _ ->
          ""
      end
    ]
  end
end
