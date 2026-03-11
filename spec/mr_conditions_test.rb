# frozen_string_literal: true

$LOAD_PATH.unshift('/home/claude/gitlab-branch-triage-rb/lib')
require 'gitlab-branch-triage'

def make_mr(iid: 1, title: "feat: something", updated_days_ago: 10,
            created_days_ago: 20, draft: false, assigned: false,
            has_reviewer: false, pipeline_status: "", labels: [],
            state: "opened")
  now = Time.now
  raw = {
    "iid"           => iid,
    "id"            => iid * 100,
    "title"         => draft ? "Draft: #{title}" : title,
    "state"         => state,
    "draft"         => draft,
    "web_url"       => "https://gitlab.example.com/mr/#{iid}",
    "source_branch" => "feature/test-#{iid}",
    "target_branch" => "main",
    "labels"        => labels,
    "author"        => { "id" => 42, "username" => "alice", "name" => "Alice" },
    "assignees"     => assigned ? [{ "id" => 42 }] : [],
    "reviewers"     => has_reviewer ? [{ "id" => 99 }] : [],
    "updated_at"    => (now - updated_days_ago * 86_400).iso8601,
    "created_at"    => (now - created_days_ago * 86_400).iso8601,
    "head_pipeline" => pipeline_status.empty? ? nil : { "status" => pipeline_status },
  }
  Gitlab::BranchTriage::Resource::MergeRequest.new(raw)
end

tests = [
  # [mr, conditions, expected, label]
  [
    make_mr(updated_days_ago: 35),
    { "date" => { "attribute" => "updated_at", "condition" => "older_than",
                  "interval_type" => "days", "interval" => 30 } },
    true, "Abandoned MR (35d without update)"
  ],
  [
    make_mr(updated_days_ago: 10),
    { "date" => { "attribute" => "updated_at", "condition" => "older_than",
                  "interval_type" => "days", "interval" => 30 } },
    false, "Recent MR (10d) does not match"
  ],
  [
    make_mr(draft: true),
    { "draft" => true },
    true, "Draft MR matches draft: true"
  ],
  [
    make_mr(draft: false),
    { "draft" => true },
    false, "Non-draft MR does not match draft: true"
  ],
  [
    make_mr(assigned: false),
    { "assigned" => false },
    true, "Unassigned MR matches assigned: false"
  ],
  [
    make_mr(has_reviewer: false, draft: false, created_days_ago: 20),
    { "has_reviewer" => false, "draft" => false },
    true, "No reviewer + not draft matches"
  ],
  [
    make_mr(pipeline_status: "failed"),
    { "pipeline_status" => "failed" },
    true, "Failed pipeline matches"
  ],
  [
    make_mr(labels: ["on-hold"]),
    { "forbidden_labels" => ["on-hold"] },
    false, "on-hold label prevents match"
  ],
  [
    make_mr(labels: ["stale"]),
    { "labels" => ["stale"] },
    true, "Label condition matches"
  ],
  [
    make_mr(updated_days_ago: 35, labels: ["on-hold"]),
    { "date" => { "attribute" => "updated_at", "condition" => "older_than",
                  "interval_type" => "days", "interval" => 30 },
      "forbidden_labels" => ["on-hold"] },
    false, "Abandoned but on-hold is excluded"
  ],
]

all_pass = true
tests.each do |mr, conditions, expected, label|
  result = Gitlab::BranchTriage::Conditions::MrEvaluator.new(mr, conditions).satisfied?
  ok     = result == expected
  all_pass = false unless ok
  puts "#{ok ? 'OK' : 'FAIL'} | #{label} | expected=#{expected} got=#{result}"
end

puts ""

# Test resource fields
mr = make_mr(iid: 7, updated_days_ago: 45, draft: true,
             labels: ["wip", "backend"], pipeline_status: "failed")
puts "Resource tests:"
puts "  days_since_update=#{mr.days_since_update} (expected ~45): #{mr.days_since_update.between?(44,46) ? 'OK' : 'FAIL'}"
puts "  draft?=#{mr.draft?} (expected true): #{mr.draft? ? 'OK' : 'FAIL'}"
puts "  pipeline_failed?=#{mr.pipeline_failed?} (expected true): #{mr.pipeline_failed? ? 'OK' : 'FAIL'}"
puts "  has_label?('wip')=#{mr.has_label?('wip')} (expected true): #{mr.has_label?('wip') ? 'OK' : 'FAIL'}"
ctx = mr.template_context
puts "  template iid=#{ctx['iid']}: #{ctx['iid'] == '7' ? 'OK' : 'FAIL'}"
puts "  template author_username=#{ctx['author_username']}: #{ctx['author_username'] == 'alice' ? 'OK' : 'FAIL'}"

puts ""
puts all_pass ? "All tests passed!" : "Some tests FAILED!"
exit(all_pass ? 0 : 1)
