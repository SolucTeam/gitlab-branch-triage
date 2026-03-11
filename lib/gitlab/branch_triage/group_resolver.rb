# frozen_string_literal: true

module Gitlab
  module BranchTriage
    # Resolves all projects under a GitLab group, recursively traversing subgroups.
    # Optionally excludes archived and/or forked projects.
    class GroupResolver
      attr_reader :client, :logger

      def initialize(client:, logger: Logger.new($stdout))
        @client = client
        @logger = logger
      end

      # Returns an array of project hashes for the given group (and all subgroups).
      #
      # @param group_id [String]  group path or numeric ID
      # @param exclude_archived [Boolean]
      # @param exclude_forks    [Boolean]
      # @return [Array<Hash>]
      def projects(group_id, exclude_archived: true, exclude_forks: true)
        @logger.info("🔍 Resolving projects for group: #{group_id}")
        @logger.info("   exclude_archived=#{exclude_archived} | exclude_forks=#{exclude_forks}")

        all_projects = fetch_all_projects(group_id)

        before = all_projects.size

        all_projects.reject! { |p| p["archived"] }        if exclude_archived
        all_projects.reject! { |p| p["forked_from_project"] } if exclude_forks

        after = all_projects.size
        @logger.info("   #{before} project(s) found → #{after} kept after filters\n")

        all_projects
      end

      private

      # Uses the GitLab API's include_subgroups param to get every project
      # in the group tree in a single paginated call.
      def fetch_all_projects(group_id)
        client.group_projects(group_id, include_subgroups: true)
      end
    end
  end
end
