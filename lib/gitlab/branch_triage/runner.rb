# frozen_string_literal: true

module Gitlab
  module BranchTriage
    class Runner
      SEPARATOR = ("=" * 60).freeze
      LINE      = ("-" * 60).freeze

      attr_reader :client, :policy_loader, :dry_run, :logger, :options

      def initialize(client:, policy_loader:, source: "projects", source_id:,
                     dry_run: true, logger: Logger.new($stdout), options: {})
        @client        = client
        @policy_loader = policy_loader
        @source        = source
        @source_id     = source_id
        @dry_run       = dry_run
        @logger        = logger
        @options       = options
        @stats         = { projects: 0, branches_matched: 0, skipped: 0, errors: 0 }
      end

      def run
        print_header

        branch_rules = policy_loader.branch_rules

        if branch_rules.empty?
          logger.warn("No rules found in policies file.")
          return
        end

        projects = resolve_projects
        if projects.empty?
          logger.warn("No projects found.")
          return
        end

        projects.each { |project| run_project(project, branch_rules) }

        print_summary(branch_rules.size)
      end

      private

      # ── Project resolution ────────────────────────────────────────────────

      def resolve_projects
        if @source == "groups"
          resolver = GroupResolver.new(client: client, logger: logger)
          resolver.projects(
            @source_id,
            exclude_archived: options.fetch(:exclude_archived, true),
            exclude_forks:    options.fetch(:exclude_forks, true)
          )
        else
          [{ "id" => @source_id, "path_with_namespace" => @source_id }]
        end
      end

      # ── Per-project processing ────────────────────────────────────────────

      def run_project(project, branch_rules)
        project_id   = project["id"] || project["path_with_namespace"]
        project_path = project["path_with_namespace"] || project_id.to_s

        logger.info("")
        logger.info(SEPARATOR)
        logger.info("  Project: #{project_path}")
        logger.info(SEPARATOR)

        @stats[:projects] += 1

        close_orphaned_issues(project_id)
        run_branch_rules(branch_rules, project_id, project_path)
      rescue => e
        logger.error("  ERROR processing #{project_path}: #{e.message}")
        @stats[:errors] += 1
      end

      # ── Orphaned issue cleanup ────────────────────────────────────────────
      #
      # Finds open branch-cleanup issues whose branch no longer exists
      # (deleted manually by the author or via another process) and closes them.

      def close_orphaned_issues(project_id)
        issues = client.project_issues(project_id, labels: "branch-cleanup")
        return if issues.empty?

        existing_branches = client.branches(project_id).map { |b| b["name"] }.to_set

        issues.each do |issue|
          # Extract branch name from issue title — matches patterns like:
          #   "🔔 Stale branch: `feature/foo`"
          branch_name = issue["title"].to_s[/`([^`]+)`/, 1]
          next unless branch_name
          next if existing_branches.include?(branch_name)

          if dry_run
            logger.info("  [DRY-RUN] Would close issue ##{issue["iid"]} — branch #{branch_name.inspect} no longer exists")
            next
          end

          client.close_issue(project_id, issue["iid"])
          logger.info("  ✅ Closed issue ##{issue["iid"]} — branch #{branch_name.inspect} no longer exists")
        rescue => e
          logger.error("  ❌ Could not close issue ##{issue["iid"]}: #{e.message}")
        end
      end

      # ── Branch rules ──────────────────────────────────────────────────────

      def run_branch_rules(rules, project_id, project_path)
        logger.info("")
        logger.info("-- Branches --")

        branches = client.branches(project_id)
        logger.info("  #{branches.size} branch(es) found")

        open_mr_branches = client.open_mr_source_branches(project_id)
        logger.info("  #{open_mr_branches.size} branch(es) with an open MR")

        resources = branches.map do |raw|
          b = Resource::Branch.new(raw, open_mr_branches: open_mr_branches)
          b.project_path = project_path
          b
        end

        rules.each { |rule| process_branch_rule(rule, resources, project_id, project_path) }
      end

      def process_branch_rule(rule, resources, project_id, project_path)
        name       = rule["name"] || "(unnamed)"
        conditions = rule["conditions"] || {}
        actions    = rule["actions"]    || {}
        limits     = rule["limits"]     || {}

        logger.info("")
        logger.info("  Rule: #{name}")

        matched = resources.select do |b|
          Conditions::Evaluator.new(b, conditions).satisfied?
        rescue => e
          logger.error("    ERROR evaluating #{b.name}: #{e.message}")
          @stats[:errors] += 1
          false
        end

        matched = matched.sort_by(&:committed_at).last(limits["most_recent"].to_i) if limits["most_recent"]

        if matched.empty?
          logger.info("    No branches matched.")
          return
        end

        @stats[:skipped] += resources.size - matched.size

        logger.info("    #{matched.size} matched:")
        delete_threshold = conditions.dig("date", "interval") || conditions["inactive_days"] || 90

        matched.each do |b|
          b.delete_in_days = [delete_threshold.to_i - b.days_inactive, 0].max
          logger.info("    Branch : #{b.name} (#{b.days_inactive}d inactive, #{b.author_name})")

          Actions::Executor.new(
            client: client, project_id: project_id, branch: b,
            actions: actions, dry_run: dry_run, logger: logger
          ).execute!

          @stats[:branches_matched] += 1
        end
      end

      # ── Helpers ───────────────────────────────────────────────────────────

      def print_header
        mode_label = @source == "groups" ? "group (recursive)" : "project"
        logger.info(SEPARATOR)
        logger.info("  gitlab-branch-triage v#{VERSION}")
        logger.info("  Source : #{@source_id} (#{mode_label})")
        logger.info("  Host   : #{client.host_url}")
        logger.info("  Mode   : #{dry_run ? 'DRY-RUN (no real actions)' : 'LIVE'}")
        if @source == "groups"
          logger.info("  Filters: exclude_archived=#{options.fetch(:exclude_archived, true)}" \
                      " | exclude_forks=#{options.fetch(:exclude_forks, true)}")
        end
        logger.info(SEPARATOR)
      end

      def print_summary(branch_rule_count)
        logger.info("")
        logger.info(LINE)
        logger.info("Summary")
        logger.info("  Projects processed  : #{@stats[:projects]}")
        logger.info("  Branch rules        : #{branch_rule_count}")
        logger.info("  Branches matched    : #{@stats[:branches_matched]}")
        logger.info("  Skipped             : #{@stats[:skipped]}")
        logger.info("  Errors              : #{@stats[:errors]}") if @stats[:errors] > 0
        if dry_run
          logger.info("")
          logger.info("DRY-RUN: no real actions were performed.")
          logger.info("Pass --no-dry-run to execute actions.")
        end
      end
    end
  end
end
