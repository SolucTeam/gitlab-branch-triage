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
        @stats         = { projects: 0, branches_matched: 0, mrs_matched: 0,
                           skipped: 0, errors: 0 }
      end

      def run
        print_header

        branch_rules = policy_loader.branch_rules
        mr_rules     = policy_loader.mr_rules

        if branch_rules.empty? && mr_rules.empty?
          logger.warn("No rules found in policies file.")
          return
        end

        projects = resolve_projects
        if projects.empty?
          logger.warn("No projects found.")
          return
        end

        projects.each { |project| run_project(project, branch_rules, mr_rules) }

        print_summary(branch_rules.size, mr_rules.size)
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

      def run_project(project, branch_rules, mr_rules)
        project_id   = project["id"] || project["path_with_namespace"]
        project_path = project["path_with_namespace"] || project_id.to_s

        logger.info("")
        logger.info(SEPARATOR)
        logger.info("  Project: #{project_path}")
        logger.info(SEPARATOR)

        @stats[:projects] += 1

        run_branch_rules(branch_rules, project_id, project_path) if branch_rules.any?
        run_mr_rules(mr_rules, project_id, project_path)         if mr_rules.any?
      rescue => e
        logger.error("  ERROR processing #{project_path}: #{e.message}")
        @stats[:errors] += 1
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

      # ── MR rules ──────────────────────────────────────────────────────────

      def run_mr_rules(rules, project_id, project_path)
        logger.info("")
        logger.info("-- Merge Requests --")

        raw_mrs = client.merge_requests(project_id, state: "opened")
        logger.info("  #{raw_mrs.size} open MR(s) found")

        mrs = raw_mrs.map do |raw|
          mr = Resource::MergeRequest.new(raw)
          mr.project_path = project_path
          mr
        end

        rules.each { |rule| process_mr_rule(rule, mrs, project_id, project_path) }
      end

      def process_mr_rule(rule, mrs, project_id, project_path)
        name       = rule["name"] || "(unnamed)"
        conditions = rule["conditions"] || {}
        actions    = rule["actions"]    || {}
        limits     = rule["limits"]     || {}

        logger.info("")
        logger.info("  Rule: #{name}")

        matched = mrs.select do |mr|
          Conditions::MrEvaluator.new(mr, conditions).satisfied?
        rescue => e
          logger.error("    ERROR evaluating MR !#{mr.iid}: #{e.message}")
          @stats[:errors] += 1
          false
        end

        if limits["most_recent"]
          matched = matched.sort_by(&:updated_at).last(limits["most_recent"].to_i)
        end

        if matched.empty?
          logger.info("    No MRs matched.")
          return
        end

        @stats[:skipped] += mrs.size - matched.size

        logger.info("    #{matched.size} matched:")

        close_threshold = conditions.dig("date", "interval") || 30

        matched.each do |mr|
          mr.close_in_days = [close_threshold.to_i - mr.days_since_update, 0].max

          logger.info("    MR !#{mr.iid} : #{mr.title.slice(0, 55)}")
          logger.info("      Author  : @#{mr.author_username}")
          logger.info("      Updated : #{mr.days_since_update}d ago | Draft: #{mr.draft?} | Labels: #{mr.labels.join(", ")}")

          Actions::MrExecutor.new(
            client: client, project_id: project_id, mr: mr,
            actions: actions, dry_run: dry_run, logger: logger
          ).execute!

          @stats[:mrs_matched] += 1
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

      def print_summary(branch_rule_count, mr_rule_count)
        logger.info("")
        logger.info(LINE)
        logger.info("Summary")
        logger.info("  Projects processed  : #{@stats[:projects]}")
        logger.info("  Branch rules        : #{branch_rule_count}")
        logger.info("  MR rules            : #{mr_rule_count}")
        logger.info("  Branches matched    : #{@stats[:branches_matched]}")
        logger.info("  MRs matched         : #{@stats[:mrs_matched]}")
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
