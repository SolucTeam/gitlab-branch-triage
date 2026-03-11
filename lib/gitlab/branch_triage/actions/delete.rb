# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Actions
      # delete: true
      #
      # Deletes the branch unconditionally.
      # Author state is checked for logging purposes only here —
      # the notify action handles the "inactive author" special case.
      class Delete < Base
        def execute
          return unless config

          if dry_run
            log_dry("Would delete branch: #{branch.name.inspect}")
            return
          end

          ok = client.delete_branch(project_id, branch.name)
          if ok
            log_ok("Branch deleted: #{branch.name.inspect}")
          else
            log_err("Failed to delete branch: #{branch.name.inspect}")
          end
        rescue => e
          log_err("Error deleting branch #{branch.name}: #{e.message}")
        end
      end
    end
  end
end
