# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Actions
      class Base
        attr_reader :client, :project_id, :branch, :config, :dry_run, :logger

        def initialize(client:, project_id:, branch:, config:, dry_run: true, logger: Logger.new($stdout))
          @client     = client
          @project_id = project_id
          @branch     = branch
          @config     = config
          @dry_run    = dry_run
          @logger     = logger
        end

        def execute
          raise NotImplementedError, "#{self.class}#execute not implemented"
        end

        protected

        def render(template, extra_ctx = {})
          ctx = branch.template_context(extra_ctx)
          # Simple {{variable}} substitution (Mustache-style, no logic needed)
          template.gsub(/\{\{(\w+)\}\}/) { ctx[$1] || "" }
        end

        def log_dry(msg)
          logger.info("  [DRY-RUN] #{msg}")
        end

        def log_ok(msg)
          logger.info("  ✅ #{msg}")
        end

        def log_err(msg)
          logger.error("  ❌ #{msg}")
        end
      end
    end
  end
end
