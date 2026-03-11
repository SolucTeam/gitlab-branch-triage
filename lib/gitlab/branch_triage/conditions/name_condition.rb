# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Conditions
      # name:
      #   matches: "^feature/.*"
      #   contains: "hotfix"
      #   starts_with: "release/"
      #   ends_with: "-wip"
      class NameCondition < Base
        def satisfied?
          match_name?(branch.name, config)
        end

        protected

        def match_name?(name, cfg)
          return Regexp.new(cfg["matches"]).match?(name)    if cfg.key?("matches")
          return name.include?(cfg["contains"])             if cfg.key?("contains")
          return name.start_with?(cfg["starts_with"])       if cfg.key?("starts_with")
          return name.end_with?(cfg["ends_with"])           if cfg.key?("ends_with")
          true
        end
      end

      # forbidden_name: — inverse of NameCondition
      class ForbiddenName < NameCondition
        def satisfied?
          !super
        end
      end
    end
  end
end
