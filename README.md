# circleCi-dynamic-config

This is the home of the global configuration for [CapSens](https://www.capsens.eu/) project's CircleCI pipelines.

It runs RSpec, handles the assets (Webpacker and Sprockets), and much more.

1. Copy the file `config.yml.example` to your project's `.circleci/config.yml`
2. Choose the appropriate template file (e.g.: `configs/rails_config.yml`).
3. If applicable, copy the file `database.yml.ci.example` to your project's `config/database.yml.ci`.
4. Adapt your `.circleci/config.yml` file with the appropriate parameters (the full list of available parameters can be found inside the template file).
    * The `project-name` config file parameter must match the `username` and `database` variables of the CI database file.


https://www.capsens.eu/
