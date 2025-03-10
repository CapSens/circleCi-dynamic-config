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


https://www.capsens.eu/
