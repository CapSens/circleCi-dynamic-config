require "simplecov"
require "simplecov_json_formatter"
require "json"

unless defined?(SimpleCovSummaryFormatter)
  class SimpleCovSummaryFormatter
    def format(result)
      payload = {
        covered_percent: result.covered_percent,
        covered_lines: result.covered_lines,
        total_lines: result.total_lines,
        covered_strength: result.covered_strength,
        covered_branches: result.covered_branches,
        total_branches: result.total_branches,
        branch_covered_percent: result.branch_covered_percent,
        groups: result.groups.transform_values { |files|
          {
            covered_percent: files.covered_percent,
            covered_lines: files.covered_lines,
            total_lines: files.lines_of_code,
            covered_strength: files.covered_strength,
            covered_branches: files.covered_branches,
            total_branches: files.total_branches,
            branch_covered_percent: files.branch_covered_percent
          }
        }
      }
      File.write(File.join(SimpleCov.coverage_path, "summary.json"), JSON.pretty_generate(payload))
    end
  end
end

unless SimpleCov.profiles.key?(:app)
  SimpleCov.profiles.define "app" do
    load_profile "rails"
    enable_coverage :branch

    formatter SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::JSONFormatter,
      SimpleCovSummaryFormatter
    ])

    add_filter "/bin/"
    add_group "Admin", "app/admin"

    track_files "{app,lib}/**/*.rb"
  end
end
