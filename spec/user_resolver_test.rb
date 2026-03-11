# frozen_string_literal: true

$LOAD_PATH.unshift('/home/claude/gitlab-branch-triage-rb/lib')
require 'gitlab-branch-triage'

# ── Mock client ───────────────────────────────────────────────────────────────

class MockClient
  attr_reader :host_url

  USERS = {
    "alice@company.com"   => { "id" => 1, "username" => "alice",   "state" => "active" },
    "bob@company.com"     => { "id" => 2, "username" => "bob",     "state" => "blocked" },
    "carol@company.com"   => { "id" => 3, "username" => "carol",   "state" => "ldap_blocked" },
    "dave@company.com"    => { "id" => 4, "username" => "dave",    "state" => "deactivated" },
    "Alice Active"        => { "id" => 1, "username" => "alice",   "state" => "active" },
  }.freeze

  OWNERS = [
    { "id" => 99, "username" => "owner1", "access_level" => 50 },
  ].freeze

  def initialize; @host_url = "https://gitlab.example.com" end

  def find_users(search, per_page: 5)
    user = USERS[search]
    user ? [user] : []
  end

  def project_members(project_id, min_access_level: 40)
    OWNERS
  end
end

# ── Tests ─────────────────────────────────────────────────────────────────────

logger   = Logger.new($stdout)
logger.formatter = proc { |_, _, _, msg| "" }  # silence logs during tests

resolver = Gitlab::BranchTriage::UserResolver.new(client: MockClient.new, logger: logger)

tests = [
  # [email, name, expected_status, expected_active?, label]
  ["alice@company.com",  "Alice Active",  :active,       true,  "Active user found by email"],
  ["bob@company.com",    "Bob Gone",      :blocked,      false, "Blocked user detected"],
  ["carol@company.com",  "Carol LDAP",    :ldap_blocked, false, "LDAP blocked (left company)"],
  ["dave@company.com",   "Dave Inactive", :deactivated,  false, "Deactivated user"],
  ["ghost@nowhere.com",  "Unknown Person",:not_found,    false, "Unknown user → not_found"],
  ["",                   "Alice Active",  :active,       true,  "Fallback to name when email empty"],
]

all_pass = true
tests.each do |email, name, expected_status, expected_active, label|
  result = resolver.resolve(email: email, name: name)
  ok_status = result.status == expected_status
  ok_active = result.active? == expected_active
  ok = ok_status && ok_active
  all_pass = false unless ok
  puts "#{ok ? 'OK' : 'FAIL'} | #{label}"
  puts "       status=#{result.status} (expected #{expected_status}) | active?=#{result.active?} (expected #{expected_active})" unless ok
end

# Test display string
result = resolver.resolve(email: "bob@company.com", name: "Bob")
puts "OK | display: #{result.display}" if result.display.include?("BLOCKED")

# Test caching (same object returned)
r1 = resolver.resolve(email: "alice@company.com", name: "Alice")
r2 = resolver.resolve(email: "alice@company.com", name: "Alice")
puts "#{r1.equal?(r2) ? 'OK' : 'FAIL'} | Result is cached (same object)"

# Test project owners
owners = resolver.project_owners("my-project")
puts "#{owners.size == 1 && owners.first["username"] == "owner1" ? 'OK' : 'FAIL'} | project_owners returns maintainers"

puts ""
puts all_pass ? "All tests passed!" : "Some tests FAILED!"
exit(all_pass ? 0 : 1)
