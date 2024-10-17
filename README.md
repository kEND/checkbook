<p align="center">
  <!-- img src="https://user-images.githubusercontent.com/11348/59598372-07ca4200-90ca-11e9-8645-88642ef06a64.png" width="600" / -->
  <br /><br />
  <code>Checkbook</code> is a set of checks to help keep your Elixir project code clean and well-factored.
  <br /><br />
	 <!-- 
	  <a href="https://github.com/mirego/credo_naming/actions?query=workflow%3ACI+branch%3Amain+event%3Apush"><img src="https://github.com/mirego/credo_naming/workflows/CI/badge.svg?branch=master&event=push" /></a>
	  <a href="https://hex.pm/packages/credo_naming"><img src="https://img.shields.io/hexpm/v/credo_naming.svg" /></a>
	 -->
</p>

## Installation

Add the `:checkbook` package to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:checkbook, "~> 0.1", only: [:dev, :test], runtime: false}
  ]
end
```

## Usage

You just need to add the checks you want in your `.credo.exs` configuration file.

### Check for public function in your modules that are unused

This check will raise an issue if a public function is defined and not used in the rest of the project.

```elixir
{Checkbook.Check.Refactor.UnusedPublicFunctions, ignore_exposed_for_testing: true}
```

Suppose you have a `MyApp.ErrorHelpers` module:

```
$ mix credo

┃  Refactoring opportunities
┃
┃ [F] → Unused public function: five_hours/0
┃       lib/my_app_web/views/view_helpers.ex #()
┃ [F] → Unused public function: year_list/0
┃       lib/my_app_web/views/view_helpers.ex #()
```

With this check configuration for example, a module named `MyApp.UserManager` or `MyApp.FormHelpers` would not be allowed.

#### Setting `ignore_exposed_for_testing`

`ignore_exposed_for_testing` is a boolean that will ignore public functions that are exposed for testing.  For example, if you have a module attribute that you want to expose for testing, you can set this to `true` to prevent the check from flagging it as unused.

## License

`Checkbook` is © 2024 [Ken Barker](https://github.com/kend) and may be freely distributed under the [MIT license](https://github.com/kend/checkbook/blob/main/LICENSE).
