# circleCi-dynamic-config

This is the home of the global configuration for [CapSens](https://www.capsens.eu/) project's CircleCI pipelines.

It runs RSpec, handles the assets (Webpacker and Sprockets), and much more.

1. Enable dynamic config for your project in CircleCI (Project Settings > Advanced > Enable dynamic config using setup workflows).
2. Copy the file `config.yml.example` to your project's `.circleci/config.yml`.
3. Choose the appropriate template file (e.g.: `configs/rails_config.yml`).
4. If applicable, copy the file `database.yml.ci.example` (or `database_mysql.yml.ci.example` if you are using the MySQL template file `configs/rails_config_mysql.yml`) to your project's `config/database.yml.ci`.
5. Adapt your `.circleci/config.yml` file with the appropriate parameters (the full list of available parameters can be found inside the template file).
    * The `project-name` config file parameter must match the `username` and `database` variables of the CI database file.
6. Don't forget to activate your project (if necessary) on CircleCI (https://app.circleci.com/projects/project-dashboard/github/CapSens/ => "Set up Project")

## Tests parallelism

You can enable the tests parallelism by providing the `tests-parallelism` variable with a value greater than 1.
It will split the RSpec suite in X smaller pipelines that should really speed up the execution time if your project's tests are slow.
Be careful, as it will spawn **real** containers. So, for example, if you set `tests-parallelism` to 3, each pipeline (commit) running on your project will effectively run 4 pipelines. That leaves that much less spots in the queue for your other projects and other pipelines to run. So, consider this option **ONLY** if this is worth it.

## Coverage report

The pipeline automatically collects SimpleCov coverage during the `spec` job and aggregates the `.resultset.json` from every (parallel) test container into a single artifact via the `coverage_report` job. It produces:

- `coverage/summary.json` — compact summary consumed by the intra
- `coverage/coverage.json` — full per-file JSON from `simplecov_json_formatter`
- `coverage/index.html` — HTML report (via SimpleCov's HTMLFormatter)

### Zero-setup default

Just add these two gems to your project's `Gemfile` (no spec/support files, no spec_helper changes needed):

```ruby
group :test do
  gem "simplecov", require: false
  gem "simplecov_json_formatter", require: false
end
```

The CI loads a shared profile from [`support/simplecov_app_profile.rb`](support/simplecov_app_profile.rb) (cloned at job runtime from this repo) — defining the `"app"` profile based on SimpleCov's `"rails"` preset, with branch coverage, MultiFormatter (HTML + JSON + summary) and `add_group "Admin", "app/admin"`. To evolve the default for **all** projects at once, edit that file in this repo.

### Project-side override (optional)

If you need a custom profile, drop a `spec/support/simplecov_profile.rb` that registers a profile named `"app"`:

```ruby
SimpleCov.profiles.define "app" do
  # add_filter / add_group / formatter ...
end
```

When present, it takes precedence over the shared default.

### Best-effort guarantee

Both the boot (during tests) and the collate step are wrapped so that any failure (missing gem, profile loading error, clone failure) is logged but never blocks a merge.

https://www.capsens.eu/
