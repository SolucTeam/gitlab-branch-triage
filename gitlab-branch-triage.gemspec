# frozen_string_literal: true

require_relative "lib/gitlab/branch_triage/version"

Gem::Specification.new do |spec|
  spec.name          = "gitlab-branch-triage"
  spec.version       = Gitlab::BranchTriage::VERSION
  spec.authors       = ["SolucTeam"]
  spec.email         = ["contact@solucteam.com"]

  spec.summary       = "Automated branch and MR triage for GitLab, driven by YAML policies"
  spec.description   = <<~DESC
    gitlab-branch-triage enables project maintainers to automatically triage
    GitLab branches and merge requests based on policies defined in a YAML file.
    Notify stale branch authors, auto-delete merged branches, close abandoned MRs,
    and detect inactive authors — all configurable via simple rules.
  DESC
  spec.homepage      = "https://github.com/solucteam/gitlab-branch-triage"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.0"

  spec.metadata = {
    "homepage_uri"          => spec.homepage,
    "source_code_uri"       => spec.homepage,
    "changelog_uri"         => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri"       => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true",
  }

  spec.files         = Dir["lib/**/*.rb", "bin/*", "*.md", "*.gemspec", "LICENSE", "logo.svg"]
  spec.bindir        = "bin"
  spec.executables   = ["gitlab-branch-triage"]
  spec.require_paths = ["lib"]

  spec.add_dependency "httparty",      "~> 0.21"
  spec.add_dependency "activesupport", "~> 7.0"
end
