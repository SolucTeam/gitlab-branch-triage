# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Resource
      # Wraps a raw GitLab MR API hash and exposes computed helpers.
      class MergeRequest
        attr_reader :raw
        attr_accessor :author_user, :project_path, :close_in_days

        def initialize(raw)
          @raw         = raw
          @author_user = nil
        end

        # ── Identity ──────────────────────────────────────────────────────────

        def iid
          raw["iid"]
        end

        def id
          raw["id"]
        end

        def title
          raw["title"].to_s
        end

        def state
          raw["state"].to_s  # opened | closed | merged | locked
        end

        def draft?
          raw["draft"] == true || title.match?(/\A\s*(Draft|WIP)\s*:/i)
        end

        def source_branch
          raw["source_branch"].to_s
        end

        def target_branch
          raw["target_branch"].to_s
        end

        def web_url
          raw["web_url"].to_s
        end

        def labels
          Array(raw["labels"])
        end

        def has_label?(name)
          labels.any? { |l| l.casecmp?(name) }
        end

        # ── Author ────────────────────────────────────────────────────────────

        def author_username
          raw.dig("author", "username").to_s
        end

        def author_name
          raw.dig("author", "name").to_s
        end

        def author_id
          raw.dig("author", "id")
        end

        # ── Assignees ─────────────────────────────────────────────────────────

        def assignees
          Array(raw["assignees"])
        end

        def assigned?
          assignees.any?
        end

        # ── Reviewers ─────────────────────────────────────────────────────────

        def reviewers
          Array(raw["reviewers"])
        end

        def has_reviewer?
          reviewers.any?
        end

        # ── Dates ─────────────────────────────────────────────────────────────

        def created_at
          @created_at ||= Time.parse(raw["created_at"]) rescue Time.now
        end

        def updated_at
          @updated_at ||= Time.parse(raw["updated_at"]) rescue Time.now
        end

        def days_since_update
          @days_since_update ||= ((Time.now - updated_at) / 86_400).to_i
        end

        def days_since_creation
          @days_since_creation ||= ((Time.now - created_at) / 86_400).to_i
        end

        # ── Pipeline ──────────────────────────────────────────────────────────

        def pipeline_status
          raw.dig("head_pipeline", "status").to_s  # success|failed|running|pending|""
        end

        def pipeline_failed?
          pipeline_status == "failed"
        end

        # ── Template context ──────────────────────────────────────────────────

        def template_context(extra = {})
          {
            "iid"                => iid.to_s,
            "title"              => title,
            "web_url"            => web_url,
            "source_branch"      => source_branch,
            "target_branch"      => target_branch,
            "author_username"    => author_username,
            "author_name"        => author_name,
            "labels"             => labels.join(", "),
            "state"              => state,
            "draft"              => draft?.to_s,
            "days_since_update"  => days_since_update.to_s,
            "days_since_creation"=> days_since_creation.to_s,
            "updated_at"         => updated_at.strftime("%Y-%m-%d"),
            "created_at"         => created_at.strftime("%Y-%m-%d"),
            "pipeline_status"    => pipeline_status,
            "today"              => Time.now.strftime("%Y-%m-%d"),
            "project_path"       => @project_path.to_s,
          }.merge(extra)
        end

        def to_s
          "#<MR !#{iid} #{title.slice(0, 40)} state=#{state} draft=#{draft?} updated=#{days_since_update}d ago>"
        end
      end
    end
  end
end
