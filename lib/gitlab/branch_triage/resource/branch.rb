# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Resource
      # Wraps a raw GitLab branch API hash and exposes computed helpers.
      class Branch
        attr_reader :raw, :open_mr
        attr_accessor :author_user, :project_path, :delete_in_days

        def initialize(raw, open_mr_branches:)
          @raw    = raw
          @open_mr = open_mr_branches.include?(raw["name"])
          @author_user = nil  # resolved lazily by actions
        end

        # ── Identity ──────────────────────────────────────────────────────────

        def name
          raw["name"]
        end

        def protected?
          raw["protected"] == true
        end

        def merged?
          raw["merged"] == true
        end

        def has_open_mr?
          @open_mr
        end

        # ── Commit ────────────────────────────────────────────────────────────

        def commit
          raw["commit"] || {}
        end

        def committed_at
          return @committed_at if defined?(@committed_at)
          @committed_at = Time.parse(commit["committed_date"]) rescue Time.now
        end

        def days_inactive
          @days_inactive ||= ((Time.now - committed_at) / 86_400).to_i
        end

        def author_name
          commit["author_name"].to_s
        end

        def author_email
          commit["author_email"].to_s
        end

        def commit_title
          commit["title"].to_s
        end

        def short_sha
          commit["id"].to_s[0, 8]
        end

        # ── Template context ──────────────────────────────────────────────────

        def template_context(extra = {})
          {
            "name"             => name,
            "author_name"      => author_name,
            "author_email"     => author_email,
            "author_username"  => author_user&.dig("username") || "",
            "committed_date"   => committed_at.strftime("%Y-%m-%d"),
            "days_inactive"    => days_inactive.to_s,
            "commit_title"     => commit_title,
            "short_sha"        => short_sha,
            "today"            => Time.now.strftime("%Y-%m-%d"),
            "project_path"     => @project_path.to_s,
          }.merge(extra)
        end

        def to_s
          "#<Branch name=#{name} inactive=#{days_inactive}d merged=#{merged?} protected=#{protected?}>"
        end
      end
    end
  end
end
