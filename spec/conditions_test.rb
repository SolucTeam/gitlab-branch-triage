# frozen_string_literal: true

$LOAD_PATH.unshift('/home/claude/gitlab-branch-triage-rb/lib')
require 'gitlab-branch-triage'

def make_branch(name:, days_ago:, merged: false, protected: false, open_mr: false)
  committed_at = (Time.now - days_ago * 86_400).iso8601
  raw = {
    "name"      => name,
    "merged"    => merged,
    "protected" => protected,
    "commit"    => {
      "committed_date" => committed_at,
      "author_name"    => "Alice Dupont",
      "author_email"   => "alice@company.com",
      "title"          => "feat: something",
      "id"             => "abc123def456",
    },
  }
  open_mrs = open_mr ? Set[name] : Set.new
  Gitlab::BranchTriage::Resource::Branch.new(raw, open_mr_branches: open_mrs)
end

tests = [
  [
    make_branch(name: "feature/x", days_ago: 70),
    { "inactive_days" => 60, "merged" => false, "protected" => false },
    true,
    "Stale unprotected branch",
  ],
  [
    make_branch(name: "feature/x", days_ago: 30),
    { "inactive_days" => 60 },
    false,
    "Not yet stale",
  ],
  [
    make_branch(name: "main", days_ago: 70, protected: true),
    { "inactive_days" => 60, "protected" => false },
    false,
    "Protected branch excluded",
  ],
  [
    make_branch(name: "feat/wip", days_ago: 5),
    { "name" => { "ends_with" => "-wip" } },
    false,
    "ends_with no match",
  ],
  [
    make_branch(name: "feat/x-wip", days_ago: 5),
    { "name" => { "ends_with" => "-wip" } },
    true,
    "ends_with match",
  ],
  [
    make_branch(name: "main", days_ago: 70),
    { "forbidden_name" => { "matches" => "^(main|master)$" } },
    false,
    "Forbidden name excluded",
  ],
  [
    make_branch(name: "feature/x", days_ago: 70, open_mr: true),
    { "has_open_mr" => false },
    false,
    "Branch with open MR excluded",
  ],
  [
    make_branch(name: "feature/x", days_ago: 5),
    { "date" => { "attribute" => "committed_date", "condition" => "more_recent_than",
                  "interval_type" => "days", "interval" => 10 } },
    true,
    "more_recent_than match",
  ],
  [
    make_branch(name: "feature/x", days_ago: 5),
    { "author" => { "email_domain" => "company.com" } },
    true,
    "Author email_domain match",
  ],
  [
    make_branch(name: "feature/x", days_ago: 5),
    { "forbidden_author" => { "email_domain" => "other.com" } },
    true,
    "Forbidden author (different domain) passes",
  ],
]

all_pass = true
tests.each do |branch, conditions, expected, label|
  result = Gitlab::BranchTriage::Conditions::Evaluator.new(branch, conditions).satisfied?
  ok     = result == expected
  all_pass = false unless ok
  status = ok ? "OK" : "FAIL"
  puts "#{status} | #{label} | expected=#{expected} got=#{result}"
end

puts ""
puts all_pass ? "All tests passed!" : "Some tests FAILED!"
exit(all_pass ? 0 : 1)
