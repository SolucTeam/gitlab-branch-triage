# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-11

### Added

-  initial commit and push beta version v1.0.0 (bfba928)

### Other

- Initial commit (123cd8b)

## [1.0.0] - 2026-03-11

### Added

- YAML-driven policy engine for branch and merge request triage
- Branch conditions: `inactive_days`, `merged`, `protected`, `has_open_mr`, `name`, `forbidden_name`, `author`, `forbidden_author`, `date`
- Branch actions: `notify`, `delete`, `print`, `comment`
- MR conditions: `date`, `draft`, `assigned`, `has_reviewer`, `pipeline_status`, `labels`, `forbidden_labels`, `target_branch`, `title`
- MR actions: `comment_mr`, `close_mr`, `label_mr`, `notify_mr`, `print`
- Inactive author detection with automatic branch deletion and owner notification
- Group-wide triage with recursive subgroup support
- Dry-run mode enabled by default
- `--init` helper to generate example policy file
- `--init-ci` helper to generate GitLab CI snippet
- Template variable system for notification messages
- Rate-limit handling with configurable max retries
- CLI with comprehensive options for token, source, host, policies, and filters

[1.0.0]: https://github.com/solucteam/gitlab-branch-triage/releases/tag/v1.0.0

[1.0.0]: https://github.com/solucteam/gitlab-branch-triage/releases/tag/v1.0.0
