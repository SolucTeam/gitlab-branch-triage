# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Actions
      # ── comment_mr ───────────────────────────────────────────────────────
      # Posts a note directly on the MR thread.
      #
      # comment_mr: |
      #   @{{author_username}} this MR has been inactive for {{days_since_update}} days.
      #   Please update it or it will be closed on {{close_date}}.
      class CommentMr < Base
        def execute
          body = render(config.to_s)

          if dry_run
            log_dry("Would comment on MR !#{mr.iid}: #{body[0, 80].inspect}...")
            return
          end

          client.add_mr_note(project_id, mr.iid, body)
          log_ok("Commented on MR !#{mr.iid}")
        rescue => e
          log_err("Failed to comment on MR !#{mr.iid}: #{e.message}")
        end

        private

        def mr = @branch
      end

      # ── close_mr ─────────────────────────────────────────────────────────
      # Closes the MR via the API.
      #
      # close_mr: true
      class CloseMr < Base
        def execute
          return unless config

          if dry_run
            log_dry("Would close MR !#{mr.iid}: #{mr.title.slice(0, 60).inspect}")
            return
          end

          client.close_mr(project_id, mr.iid)
          log_ok("Closed MR !#{mr.iid}: #{mr.title.slice(0, 60)}")
        rescue => e
          log_err("Failed to close MR !#{mr.iid}: #{e.message}")
        end

        private

        def mr = @branch
      end

      # ── label_mr ─────────────────────────────────────────────────────────
      # Adds labels to the MR.
      #
      # label_mr:
      #   - stale
      #   - needs-attention
      class LabelMr < Base
        def execute
          labels = Array(config)
          return if labels.empty?

          if dry_run
            log_dry("Would add labels #{labels.inspect} to MR !#{mr.iid}")
            return
          end

          client.add_mr_labels(project_id, mr.iid, labels)
          log_ok("Added labels #{labels.inspect} to MR !#{mr.iid}")
        rescue => e
          log_err("Failed to label MR !#{mr.iid}: #{e.message}")
        end

        private

        def mr = @branch
      end

      # ── notify_mr ────────────────────────────────────────────────────────
      # Creates a GitLab issue to notify the author of an abandoned MR.
      #
      # notify_mr:
      #   title: "Abandoned MR: {{title}}"
      #   body: |
      #     @{{author_username}}, MR !{{iid}} has been inactive for {{days_since_update}} days.
      #   labels:
      #     - mr-cleanup
      class NotifyMr < Base
        DEFAULT_TITLE = "Abandoned MR: !{{iid}} {{title}}"
        DEFAULT_BODY  = <<~BODY
          Hi @{{author_username}} 👋

          Merge Request [!{{iid}} {{title}}]({{web_url}}) in project `{{project_path}}`
          has been inactive for **{{days_since_update}} days**
          (last update: `{{updated_at}}`).

          **Status:** {{state}}{{draft_label}}

          Please take one of the following actions before **{{close_date}}**:
          - ✅ Mark it as ready and request a review
          - 🔄 Rebase/update if there are conflicts
          - 🚫 Close it if the work is no longer needed

          _This issue was created automatically by gitlab-branch-triage._
        BODY

        def execute
          title_tpl = config.is_a?(Hash) ? config["title"] || DEFAULT_TITLE : DEFAULT_TITLE
          body_tpl  = config.is_a?(Hash) ? config["body"]  || DEFAULT_BODY  : DEFAULT_BODY
          labels    = config.is_a?(Hash) ? Array(config["labels"])           : ["mr-cleanup", "automated"]

          close_in   = mr.instance_variable_defined?(:@close_in_days) ? mr.instance_variable_get(:@close_in_days) : 30
          close_date = (Time.now + close_in * 86_400).strftime("%Y-%m-%d")
          draft_lbl  = mr.draft? ? " (Draft/WIP)" : ""

          extra = { "close_date" => close_date, "draft_label" => draft_lbl }
          title = render(title_tpl, extra)
          body  = render(body_tpl,  extra)

          if dry_run
            log_dry("Would create issue: #{title.inspect}")
            return
          end

          issue = client.create_issue(
            project_id,
            title:       title,
            description: body,
            labels:      labels,
            assignee_id: mr.author_id
          )
          log_ok("Issue created: #{issue["web_url"]}")
        rescue => e
          log_err("Failed to create issue for MR !#{mr.iid}: #{e.message}")
        end

        private

        def mr = @branch
      end

      # ── MR Action Executor ────────────────────────────────────────────────

      MR_REGISTRY = {
        "comment_mr" => CommentMr,
        "close_mr"   => CloseMr,
        "label_mr"   => LabelMr,
        "notify_mr"  => NotifyMr,
        "print"      => Print,   # shared with branch actions
      }.freeze

      class MrExecutor
        def initialize(client:, project_id:, mr:, actions:, dry_run: true, logger: Logger.new($stdout))
          @client     = client
          @project_id = project_id
          @mr         = mr
          @actions    = actions || {}
          @dry_run    = dry_run
          @logger     = logger
        end

        def execute!
          @actions.each do |key, config|
            klass = MR_REGISTRY[key]
            if klass.nil?
              @logger.warn("  Unknown MR action '#{key}' — ignored")
              next
            end

            klass.new(
              client:     @client,
              project_id: @project_id,
              branch:     @mr,      # reuse :branch slot for MR
              config:     config,
              dry_run:    @dry_run,
              logger:     @logger
            ).execute
          end
        end
      end
    end
  end
end
