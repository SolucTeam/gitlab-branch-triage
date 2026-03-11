# frozen_string_literal: true

module Gitlab
  module BranchTriage
    class Client
      include HTTParty

      BASE_PATH = "/api/v4"

      attr_reader :host_url, :logger

      def initialize(host_url:, token:, logger: Logger.new($stdout))
        @host_url = host_url.chomp("/")
        @token    = token
        @logger   = logger

        self.class.base_uri "#{@host_url}#{BASE_PATH}"
        self.class.headers "PRIVATE-TOKEN" => token, "Content-Type" => "application/json"
      end

      # ── Branch endpoints ───────────────────────────────────────────────────

      def branches(project_id)
        paginate("/projects/#{encode(project_id)}/repository/branches")
      end

      def delete_branch(project_id, branch_name)
        path = "/projects/#{encode(project_id)}/repository/branches/#{encode(branch_name)}"
        resp = self.class.delete(path)
        handle_response!(resp, expect: 204)
        true
      end

      # ── Merge Request endpoints ────────────────────────────────────────────

      def open_mr_source_branches(project_id)
        mrs = paginate("/projects/#{encode(project_id)}/merge_requests", state: "opened")
        mrs.map { |mr| mr["source_branch"] }.to_set
      end

      def merge_requests(project_id, state: "opened")
        paginate("/projects/#{encode(project_id)}/merge_requests", state: state)
      end

      def add_mr_note(project_id, mr_iid, body)
        resp = self.class.post(
          "/projects/#{encode(project_id)}/merge_requests/#{mr_iid}/notes",
          body: { body: body }.to_json
        )
        handle_response!(resp, expect: 201)
        resp.parsed_response
      end

      def close_mr(project_id, mr_iid)
        resp = self.class.put(
          "/projects/#{encode(project_id)}/merge_requests/#{mr_iid}",
          body: { state_event: "close" }.to_json
        )
        handle_response!(resp)
        resp.parsed_response
      end

      def add_mr_labels(project_id, mr_iid, labels)
        resp = self.class.put(
          "/projects/#{encode(project_id)}/merge_requests/#{mr_iid}",
          body: { add_labels: labels.join(",") }.to_json
        )
        handle_response!(resp)
        resp.parsed_response
      end

      # ── Issue endpoints ────────────────────────────────────────────────────

      def create_issue(project_id, title:, description:, labels: [], assignee_id: nil)
        payload = { title: title, description: description, labels: labels.join(",") }
        payload[:assignee_id] = assignee_id if assignee_id

        resp = self.class.post("/projects/#{encode(project_id)}/issues", body: payload.to_json)
        handle_response!(resp, expect: 201)
        resp.parsed_response
      end

      def add_note(project_id, issue_iid, body)
        resp = self.class.post(
          "/projects/#{encode(project_id)}/issues/#{issue_iid}/notes",
          body: { body: body }.to_json
        )
        handle_response!(resp, expect: 201)
        resp.parsed_response
      end

      # ── Group endpoints ───────────────────────────────────────────────────

      # Returns all projects in a group, including subgroups recursively.
      # The GitLab API supports include_subgroups=true natively.
      def group_projects(group_id, include_subgroups: true)
        paginate(
          "/groups/#{encode(group_id)}/projects",
          include_subgroups: include_subgroups,
          with_shared:       false
        )
      end

      # ── User endpoints ─────────────────────────────────────────────────────

      # Search users — includes blocked users if token has admin scope,
      # otherwise only returns active accounts.
      def find_users(search, per_page: 5)
        resp = self.class.get("/users", query: { search: search, per_page: per_page })
        data = resp.parsed_response
        data.is_a?(Array) ? data : []
      end

      # Kept for backward compat
      def find_user(search)
        find_users(search, per_page: 1).first
      end

      # Returns project members with at least min_access_level.
      # access_level: 40 = Maintainer, 50 = Owner
      def project_members(project_id, min_access_level: 40)
        paginate(
          "/projects/#{encode(project_id)}/members/all",
          min_access_level: min_access_level
        )
      end

      private

      MAX_RETRIES = 5

      def paginate(path, extra_params = {})
        results = []
        page    = 1
        retries = 0

        loop do
          resp = self.class.get(path, query: { per_page: 100, page: page }.merge(extra_params))

          # Handle rate limiting with max retries
          if resp.code == 429
            retries += 1
            raise "Rate limited by GitLab API after #{MAX_RETRIES} retries" if retries > MAX_RETRIES

            wait = (resp.headers["retry-after"] || 10).to_i
            @logger.warn("Rate limited — waiting #{wait}s (retry #{retries}/#{MAX_RETRIES})")
            sleep(wait)
            next
          end

          retries = 0  # reset on success

          handle_response!(resp)
          data = resp.parsed_response
          break if data.empty?

          results.concat(data)
          break if data.size < 100

          page += 1
        end

        results
      end

      def handle_response!(resp, expect: 200)
        return if resp.code == expect || (expect == 200 && resp.success?)

        raise "GitLab API error #{resp.code}: #{resp.body&.slice(0, 200)}"
      end

      def encode(str)
        URI.encode_www_form_component(str.to_s)
      end
    end
  end
end
