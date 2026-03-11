# frozen_string_literal: true

module Gitlab
  module BranchTriage
    # Resolves a GitLab user from a git commit (email + name) and determines
    # whether that user is still active in the GitLab instance.
    #
    # Possible resolution outcomes:
    #
    #   :active   — user found and active → notify normally
    #   :blocked  — user found but blocked (suspended)
    #   :ldap_blocked — user blocked via LDAP/SSO (left company)
    #   :deactivated  — user manually deactivated by admin
    #   :not_found    — no GitLab account matches email or name
    #   :deleted      — ghost user (account was deleted)
    #
    # In all non-active cases → branch should be deleted directly.
    class UserResolver
      INACTIVE_STATES = %w[blocked ldap_blocked deactivated].freeze

      Result = Struct.new(:user, :status, :reason, keyword_init: true) do
        def active?    = status == :active
        def inactive?  = !active?

        def display
          case status
          when :active      then "@#{user["username"]} (active)"
          when :blocked     then "@#{user["username"]} (BLOCKED)"
          when :ldap_blocked then "@#{user["username"]} (LDAP BLOCKED — likely left company)"
          when :deactivated then "@#{user["username"]} (deactivated)"
          when :not_found   then "unknown (no GitLab account for '#{reason}')"
          when :deleted     then "ghost/deleted account"
          end
        end
      end

      def initialize(client:, logger: Logger.new($stdout))
        @client = client
        @logger = logger
        @cache  = {}
      end

      # Resolves a branch author.
      # Tries email first, then display name as fallback.
      #
      # @param email [String]
      # @param name  [String]
      # @return [Result]
      def resolve(email:, name:)
        cache_key = "#{email}|#{name}"
        return @cache[cache_key] if @cache.key?(cache_key)

        @cache[cache_key] = begin
          # 1. Try by email (most reliable)
          result = try_resolve(email) if email && !email.empty?

          # 2. Fallback: try by display name
          if result.nil? && name && !name.empty?
            result = try_resolve(name)
          end

          result || Result.new(user: nil, status: :not_found, reason: (!email.nil? && !email.empty? ? email : name))
        end
      end

      # Fetch project owners (Maintainer/Owner role = access_level >= 40).
      # Used as fallback assignee when the branch author is inactive.
      #
      # @param project_id [String|Integer]
      # @return [Array<Hash>]  array of GitLab user hashes
      def project_owners(project_id)
        @client.project_members(project_id, min_access_level: 40)
      rescue => e
        @logger.warn("  Could not fetch project owners: #{e.message}")
        []
      end

      private

      def try_resolve(search)
        # Use the admin-scoped endpoint if available (returns blocked users too).
        # Falls back to public /users which only returns active accounts.
        users = @client.find_users(search)
        return nil if users.nil? || users.empty?

        user = users.first

        # GitLab returns state: "active" | "blocked" | "ldap_blocked" |
        #                        "deactivated" | "banned"
        state = user["state"].to_s

        if state == "active"
          Result.new(user: user, status: :active, reason: nil)
        elsif INACTIVE_STATES.include?(state)
          Result.new(user: user, status: state.to_sym, reason: state)
        else
          # Unknown state — treat as inactive to be safe
          Result.new(user: user, status: :blocked, reason: "unknown state: #{state}")
        end
      end
    end
  end
end
