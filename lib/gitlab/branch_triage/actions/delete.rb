# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Actions
      # delete: true
      #
      # Deletes the branch and closes any open branch-cleanup issue
      # that was created by the notify action for this branch.
      class Delete < Base
        def execute
          return unless config

          if dry_run
            log_dry("Would delete branch: #{branch.name.inspect}")
            log_dry("Would close open branch-cleanup issue for: #{branch.name.inspect}")
            return
          end

          ok = client.delete_branch(project_id, branch.name)
          if ok
            log_ok("Branch deleted: #{branch.name.inspect}")
            close_notify_issue
          else
            log_err("Failed to delete branch: #{branch.name.inspect}")
          end
        rescue => e
          log_err("Error deleting branch #{branch.name}: #{e.message}")
        end

        private

        def close_notify_issue
          issues = client.project_issues(
            project_id,
            labels: "branch-cleanup",
            search: branch.name
          )

          matching = issues.select { |i| i["title"].to_s.include?(branch.name) }

          if matching.empty?
            logger.debug("    No open branch-cleanup issue found for #{branch.name.inspect}")
            return
          end

          matching.each do |issue|
            client.close_issue(project_id, issue["iid"])
            log_ok("Closed issue ##{issue["iid"]}: #{issue["title"]}")
          end
        rescue => e
          log_err("Could not close issue for #{branch.name}: #{e.message}")
        end
      end
    end
  end
end
