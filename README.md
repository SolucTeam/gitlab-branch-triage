<p align="center">
  <img src="logo.svg" alt="gitlab-branch-triage" width="560"/>
</p>

<p align="center">
  <a href="https://rubygems.org/gems/gitlab-branch-triage"><img src="https://img.shields.io/gem/v/gitlab-branch-triage?color=E24329&style=for-the-badge&logo=rubygems&logoColor=white" alt="Gem Version"/></a>
  <a href="https://rubygems.org/gems/gitlab-branch-triage"><img src="https://img.shields.io/gem/dt/gitlab-branch-triage?color=6B4FBB&style=for-the-badge&logo=rubygems&logoColor=white" alt="Downloads"/></a>
  <a href="https://github.com/solucteam/gitlab-branch-triage/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/solucteam/gitlab-branch-triage/ci.yml?style=for-the-badge&logo=github&label=CI" alt="CI"/></a>
  <img src="https://img.shields.io/badge/ruby-%3E%3D%203.0-CC342D?style=for-the-badge&logo=ruby&logoColor=white" alt="Ruby >= 3.0"/>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/solucteam/gitlab-branch-triage?color=FCA326&style=for-the-badge" alt="License"/></a>
</p>

---

**gitlab-branch-triage** automates branch and merge request cleanup on GitLab using YAML-driven policies. Notify stale branch authors, auto-delete merged branches, close abandoned MRs, detect inactive authors, and keep your repositories clean — all from a single configuration file.

## Features

- **Policy-driven** — define triage rules in a simple YAML file
- **Branch triage** — detect stale, merged, or abandoned branches and act on them
- **MR triage** — warn about abandoned MRs, close stale ones, flag failing pipelines
- **Inactive author detection** — automatically handles branches from blocked/deleted users
- **Group-wide** — triage all projects in a GitLab group (subgroups included recursively)
- **Dry-run by default** — safe to test before executing real actions
- **GitLab CI ready** — ship as a scheduled pipeline job

## Installation

```bash
gem install gitlab-branch-triage
```

Or add to your `Gemfile`:

```ruby
gem "gitlab-branch-triage"
```

## Quick Start

**1. Generate an example policy file:**

```bash
gitlab-branch-triage --init
```

This creates `.branch-triage-policies.yml` with sensible defaults.

**2. Run a dry-run against a project:**

```bash
export GITLAB_TOKEN="glpat-xxxxx"  # needs api scope

# Single project
gitlab-branch-triage --source-id my-group/my-project

# Entire group (all subgroups included)
gitlab-branch-triage --source groups --source-id my-group
```

**3. Execute real actions:**

```bash
gitlab-branch-triage --source-id my-group/my-project --no-dry-run
```

## Configuration

Policies are defined in `.branch-triage-policies.yml`. The file has two main sections: `branches` rules and `merge_requests` rules.

### Branch Rules

```yaml
resource_rules:
  branches:
    rules:
      - name: Notify stale branches (60+ days)
        conditions:
          inactive_days: 60
          merged: false
          protected: false
          has_open_mr: false
          forbidden_name:
            matches: "^(main|master|develop)$"
        limits:
          most_recent: 50
        actions:
          notify:
            title: "Stale branch: `{{name}}` in {{project_path}}"
            body: |
              @{{author_username}}, branch `{{name}}` has been inactive
              for **{{days_inactive}} days**. It will be deleted on **{{delete_date}}**.
            labels:
              - branch-cleanup

      - name: Delete abandoned branches (90+ days)
        conditions:
          inactive_days: 90
          merged: false
          protected: false
        actions:
          delete: true
```

### Branch Conditions

| Condition | Example | Description |
|-----------|---------|-------------|
| `inactive_days` | `60` | Days since last commit |
| `merged` | `true` / `false` | Branch merge status |
| `protected` | `true` / `false` | Branch protection status |
| `has_open_mr` | `true` / `false` | Has an open merge request |
| `name` | `{matches: "^feature/.*"}` | Branch name pattern (`matches`, `contains`, `starts_with`, `ends_with`) |
| `forbidden_name` | `{matches: "^main$"}` | Exclude branches by name |
| `author` | `{email_domain: "company.com"}` | Filter by author (`email_domain`, `name_matches`, `username`) |
| `forbidden_author` | `{email_domain: "bot.com"}` | Exclude by author |
| `date` | see below | Flexible date matching |

**Date condition:**

```yaml
date:
  attribute: committed_date
  condition: older_than       # or more_recent_than
  interval_type: days         # days | weeks | months | years
  interval: 60
```

### Branch Actions

| Action | Config | Description |
|--------|--------|-------------|
| `notify` | `{title, body, labels}` | Create an issue to notify the author |
| `delete` | `true` | Delete the branch |
| `print` | `"template string"` | Log a message |
| `comment` | `{issue_iid, body}` | Comment on an existing issue |

### Merge Request Rules

```yaml
resource_rules:
  merge_requests:
    rules:
      - name: Warn abandoned MRs (30+ days)
        conditions:
          date:
            attribute: updated_at
            condition: older_than
            interval_type: days
            interval: 30
          forbidden_labels:
            - do-not-close
        actions:
          label_mr:
            - stale
          comment_mr: |
            @{{author_username}}, this MR has had no activity for **{{days_since_update}} days**.

      - name: Close abandoned MRs (60+ days)
        conditions:
          date:
            attribute: updated_at
            condition: older_than
            interval_type: days
            interval: 60
        actions:
          close_mr: true
```

### MR Conditions

| Condition | Example | Description |
|-----------|---------|-------------|
| `date` | `{attribute: updated_at, ...}` | Filter by `updated_at` or `created_at` |
| `draft` | `true` / `false` | Draft/WIP status |
| `assigned` | `true` / `false` | Has assignees |
| `has_reviewer` | `true` / `false` | Has reviewers |
| `pipeline_status` | `"failed"` | Pipeline state (`success`, `failed`, `running`, `pending`) |
| `labels` | `["label1"]` | All labels must match (AND) |
| `forbidden_labels` | `["on-hold"]` | None must match |
| `target_branch` | `"main"` or `{matches: "regex"}` | Target branch filter |
| `title` | `{contains: "hotfix"}` | Title pattern matching |

### MR Actions

| Action | Config | Description |
|--------|--------|-------------|
| `comment_mr` | `"template"` | Post a comment on the MR |
| `close_mr` | `true` | Close the MR |
| `label_mr` | `["stale"]` | Add labels |
| `notify_mr` | `{title, body, labels}` | Create a notification issue |
| `print` | `"template"` | Log a message |

### Template Variables

**Branches:** `{{name}}`, `{{author_name}}`, `{{author_email}}`, `{{author_username}}`, `{{committed_date}}`, `{{days_inactive}}`, `{{delete_date}}`, `{{commit_title}}`, `{{short_sha}}`, `{{project_path}}`, `{{today}}`

**Merge Requests:** `{{iid}}`, `{{title}}`, `{{web_url}}`, `{{source_branch}}`, `{{target_branch}}`, `{{author_username}}`, `{{author_name}}`, `{{labels}}`, `{{state}}`, `{{draft}}`, `{{days_since_update}}`, `{{days_since_creation}}`, `{{updated_at}}`, `{{pipeline_status}}`, `{{close_date}}`, `{{project_path}}`, `{{today}}`

## CLI Options

```
Usage: gitlab-branch-triage [options]

Connection:
  -t, --token TOKEN              GitLab API token (or GITLAB_TOKEN env var)
  -H, --host-url URL             GitLab host (default: https://gitlab.com)

Source:
  -s, --source TYPE              'projects' (default) or 'groups'
  -i, --source-id ID             Project or group path/ID

Group filters:
  --[no-]exclude-archived        Exclude archived projects (default: true)
  --[no-]exclude-forks           Exclude forked projects (default: true)

Policies:
  -f, --policies-file FILE       YAML file (default: .branch-triage-policies.yml)

Behaviour:
  -n, --dry-run                  Don't perform real actions (default: on)
  --no-dry-run                   Execute real actions
  -d, --debug                    Print extra debug information

Helpers:
  --init                         Create example policy file
  --init-ci                      Print example .gitlab-ci.yml snippet
  -v, --version                  Print version
  -h, --help                     Print help
```

## GitLab CI Integration

Run as a scheduled pipeline job:

```yaml
branch-triage:
  stage: triage
  image: ruby:3.2-slim
  before_script:
    - gem install gitlab-branch-triage --no-document
  script:
    - gitlab-branch-triage --token $GITLAB_TOKEN --source-id $CI_PROJECT_PATH --no-dry-run
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
    - if: $CI_PIPELINE_SOURCE == "web"
      when: manual
  allow_failure: true
```

Generate the snippet with `gitlab-branch-triage --init-ci`.

## Inactive Author Detection

When the `notify` action detects that a branch author is inactive (blocked, deactivated, or deleted from GitLab), it automatically deletes the branch and creates a cleanup issue assigned to a project maintainer. This prevents stale notifications to users who can no longer act on them.

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/solucteam/gitlab-branch-triage).

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

## License

Released under the [MIT License](LICENSE). Copyright (c) 2026 SolucTeam.
