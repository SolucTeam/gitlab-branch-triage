# frozen_string_literal: true

module Gitlab
  module BranchTriage
    class PolicyLoader
      class InvalidPolicyError < StandardError; end

      def self.load(path)
        raise InvalidPolicyError, "Policy file not found: #{path}" unless File.exist?(path)

        raw = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
        raise InvalidPolicyError, "Policy file is empty or invalid YAML" unless raw.is_a?(Hash)
        raise InvalidPolicyError, "Missing 'resource_rules' key"         unless raw.key?("resource_rules")

        new(raw)
      rescue Psych::SyntaxError => e
        raise InvalidPolicyError, "YAML syntax error in #{path}: #{e.message}"
      end

      attr_reader :raw

      def initialize(raw)
        @raw = raw
      end

      def branch_rules
        raw.dig("resource_rules", "branches", "rules") || []
      end

      def mr_rules
        raw.dig("resource_rules", "merge_requests", "rules") || []
      end
    end
  end
end
