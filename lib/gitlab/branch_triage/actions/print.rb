# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Actions
      # print: "Branch {{name}} is {{days_inactive}} days old."
      class Print < Base
        def execute
          msg = render(config.to_s)
          logger.info("  📢 #{msg}")
        end
      end

      # comment:
      #   issue_iid: 42
      #   body: "Reminder: {{name}} is still inactive after {{days_inactive}} days."
      class Comment < Base
        def execute
          unless config.is_a?(Hash) && config["issue_iid"] && config["body"]
            log_err("'comment' action requires 'issue_iid' and 'body' keys")
            return
          end

          body = render(config["body"])
          iid  = config["issue_iid"].to_i

          if dry_run
            log_dry("Would comment on issue ##{iid}: #{body[0, 80].inspect}...")
            return
          end

          client.add_note(project_id, iid, body)
          log_ok("Commented on issue ##{iid}")
        rescue => e
          log_err("Failed to comment: #{e.message}")
        end
      end
    end
  end
end
