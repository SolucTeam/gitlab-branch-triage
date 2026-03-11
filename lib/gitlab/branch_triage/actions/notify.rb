# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Actions
      # notify:
      #   title: "🔔 Stale branch: {{name}}"
      #   body: |
      #     @{{author_username}}, branch `{{name}}` inactive for {{days_inactive}} days.
      #   labels:
      #     - branch-cleanup
      #
      # Behaviour when author is inactive/blocked/deleted:
      #   → Branch is deleted automatically (no point notifying a ghost).
      #   → An issue is still created and assigned to a project owner so the
      #     team knows a cleanup happened.
      class Notify < Base
        DEFAULT_TITLE = "🔔 Stale branch: `{{name}}`"
        DEFAULT_BODY  = <<~BODY
          Hi @{{author_username}} 👋

          Branch `{{name}}` has been inactive for **{{days_inactive}} days**
          (last commit on `{{committed_date}}`).

          It will be **automatically deleted on {{delete_date}}** unless you take action.

          **What you can do:**
          - 🔀 Open a Merge Request if this work needs to be merged
          - 🗑️ Delete the branch manually if it's no longer needed
          - 💬 Comment on this issue to request more time

          _This issue was created automatically by gitlab-branch-triage._
        BODY

        INACTIVE_AUTHOR_TITLE = "🗑️ Branch auto-deleted: `{{name}}` (author inactive)"
        INACTIVE_AUTHOR_BODY  = <<~BODY
          Branch `{{name}}` was **automatically deleted** because its author
          is no longer active on this GitLab instance.

          | Field | Value |
          |-------|-------|
          | Branch | `{{name}}` |
          | Last commit | `{{committed_date}}` |
          | Days inactive | {{days_inactive}} |
          | Git author | {{author_name}} &lt;{{author_email}}&gt; |
          | Author status | {{author_status}} |

          _This issue was created automatically by gitlab-branch-triage._
        BODY

        def execute
          resolver = UserResolver.new(client: client, logger: logger)
          result   = resolver.resolve(
            email: branch.author_email,
            name:  branch.author_name
          )

          logger.info("    Author resolution: #{result.display}")

          if result.inactive?
            handle_inactive_author(result, resolver)
          else
            # Store resolved user on branch for template rendering
            branch.author_user = result.user
            notify_active_author
          end
        end

        private

        # ── Inactive author → delete branch + notify owners ──────────────────

        def handle_inactive_author(result, resolver)
          logger.info("    Author is inactive (#{result.status}) — branch will be deleted")

          # 1. Delete the branch
          if dry_run
            log_dry("Would delete branch #{branch.name.inspect} (inactive author: #{result.status})")
          else
            ok = client.delete_branch(project_id, branch.name)
            if ok
              log_ok("Branch deleted: #{branch.name.inspect} (author #{result.status})")
            else
              log_err("Failed to delete branch #{branch.name.inspect}")
              return
            end
          end

          # 2. Notify owners so they're aware of the cleanup
          owners = resolver.project_owners(project_id)
          owner  = owners.first
          logger.warn("    No project owners/maintainers found for #{project_id}") if owner.nil?

          title = render(INACTIVE_AUTHOR_TITLE)
          body  = render(INACTIVE_AUTHOR_BODY, "author_status" => result.status.to_s)

          if dry_run
            log_dry("Would create cleanup issue for owners: #{title.inspect}")
            return
          end

          issue = client.create_issue(
            project_id,
            title:       title,
            description: body,
            labels:      ["branch-cleanup", "author-inactive", "automated"],
            assignee_id: owner&.dig("id")
          )
          log_ok("Cleanup issue created for owners: #{issue["web_url"]}")
        rescue => e
          log_err("Error handling inactive author for #{branch.name}: #{e.message}")
        end

        # ── Active author → normal notification ───────────────────────────────

        def notify_active_author
          title_tpl  = config.is_a?(Hash) ? config["title"] || DEFAULT_TITLE : DEFAULT_TITLE
          body_tpl   = config.is_a?(Hash) ? config["body"]  || DEFAULT_BODY  : DEFAULT_BODY
          labels     = config.is_a?(Hash) ? Array(config["labels"])           : []
          delete_in  = branch.delete_in_days || 30

          delete_date = (Time.now + delete_in * 86_400).strftime("%Y-%m-%d")
          title = render(title_tpl, "delete_date" => delete_date)
          body  = render(body_tpl,  "delete_date" => delete_date)

          if dry_run
            log_dry("Would create issue: #{title.inspect}")
            return
          end

          issue = client.create_issue(
            project_id,
            title:       title,
            description: body,
            labels:      labels,
            assignee_id: branch.author_user&.dig("id")
          )
          log_ok("Issue created: #{issue["web_url"]}")
        rescue => e
          log_err("Failed to create issue: #{e.message}")
        end
      end
    end
  end
end
