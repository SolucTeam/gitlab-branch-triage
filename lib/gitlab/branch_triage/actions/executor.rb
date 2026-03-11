# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Actions
      REGISTRY = {
        "notify"  => Notify,
        "delete"  => Delete,
        "print"   => Print,
        "comment" => Comment,
      }.freeze

      class Executor
        def initialize(client:, project_id:, branch:, actions:, dry_run: true, logger: Logger.new($stdout))
          @client     = client
          @project_id = project_id
          @branch     = branch
          @actions    = actions || {}
          @dry_run    = dry_run
          @logger     = logger
        end

        def execute!
          @actions.each do |key, config|
            klass = REGISTRY[key]
            if klass.nil?
              @logger.warn("  ⚠️  Unknown action '#{key}' — ignored")
              next
            end

            klass.new(
              client:     @client,
              project_id: @project_id,
              branch:     @branch,
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
