# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Conditions
      # ── MR-specific conditions ────────────────────────────────────────────

      # date:
      #   attribute: updated_at | created_at
      #   condition: older_than | more_recent_than
      #   interval_type: days | weeks | months | years
      #   interval: 30
      class MrDateCondition < Base
        MULTIPLIERS = { "days" => 1, "weeks" => 7, "months" => 30, "years" => 365 }.freeze

        def satisfied?
          threshold = config["interval"].to_i * MULTIPLIERS.fetch(config["interval_type"] || "days", 1)
          age       = case config["attribute"]
                      when "created_at" then resource.days_since_creation
                      else                   resource.days_since_update
                      end

          case config["condition"]
          when "older_than"       then age >= threshold
          when "more_recent_than" then age <  threshold
          else false
          end
        end

        private

        def resource = @branch  # reuse Base's @branch ivar (holds the MR here)
      end

      # draft: true | false
      class MrDraft < Base
        def satisfied?
          @branch.draft? == config
        end
      end

      # assigned: true | false
      class MrAssigned < Base
        def satisfied?
          @branch.assigned? == config
        end
      end

      # has_reviewer: true | false
      class MrHasReviewer < Base
        def satisfied?
          @branch.has_reviewer? == config
        end
      end

      # pipeline_status: "failed" | "success" | "running" | ""
      class MrPipelineStatus < Base
        def satisfied?
          @branch.pipeline_status == config.to_s
        end
      end

      # labels:
      #   - needs-review
      class MrLabels < Base
        def satisfied?
          Array(config).all? { |l| @branch.has_label?(l) }
        end
      end

      # forbidden_labels:
      #   - do-not-close
      class MrForbiddenLabels < Base
        def satisfied?
          Array(config).none? { |l| @branch.has_label?(l) }
        end
      end

      # target_branch: main
      class MrTargetBranch < Base
        def satisfied?
          case config
          when String then @branch.target_branch == config
          when Hash
            return Regexp.new(config["matches"]).match?(@branch.target_branch) if config["matches"]
            true
          else true
          end
        end
      end

      # ── MR Evaluator ─────────────────────────────────────────────────────

      MR_REGISTRY = {
        "date"            => MrDateCondition,
        "draft"           => MrDraft,
        "assigned"        => MrAssigned,
        "has_reviewer"    => MrHasReviewer,
        "pipeline_status" => MrPipelineStatus,
        "labels"          => MrLabels,
        "forbidden_labels"=> MrForbiddenLabels,
        "target_branch"   => MrTargetBranch,
        # title/name reuse existing conditions via alias
        "title"           => nil,
      }.freeze

      class MrEvaluator
        def initialize(mr, conditions)
          @mr         = mr
          @conditions = conditions || {}
        end

        def satisfied?
          @conditions.all? do |key, value|
            evaluate(key, value)
          end
        end

        private

        def evaluate(key, value)
          klass = MR_REGISTRY[key]

          # title: reuse NameCondition logic
          if key == "title"
            return Conditions::NameCondition.new(@mr, value).tap do |c|
              c.instance_variable_set(:@branch, OpenStruct.new(name: @mr.title))
            end.satisfied?
          end

          if klass.nil?
            warn "  Unknown MR condition '#{key}' — ignored"
            return true
          end

          klass.new(@mr, value).satisfied?
        end
      end
    end
  end
end
