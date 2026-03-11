# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Conditions
      # Maps condition keys from the YAML to their handler classes.
      REGISTRY = {
        "date"             => DateCondition,
        "inactive_days"    => InactiveDays,
        "name"             => NameCondition,
        "forbidden_name"   => ForbiddenName,
        "merged"           => nil,   # handled inline (StateCondition)
        "protected"        => nil,
        "has_open_mr"      => nil,
        "author"           => AuthorCondition,
        "forbidden_author" => ForbiddenAuthor,
      }.freeze

      STATE_KEYS = %w[merged protected has_open_mr].freeze

      class Evaluator
        def initialize(branch, conditions)
          @branch     = branch
          @conditions = conditions || {}
        end

        # Returns true if ALL conditions are satisfied.
        def satisfied?
          @conditions.all? do |key, value|
            evaluate_condition(key, value)
          end
        end

        private

        def evaluate_condition(key, value)
          if STATE_KEYS.include?(key)
            return StateCondition.for(key, @branch, value).satisfied?
          end

          klass = REGISTRY[key]
          if klass.nil? && !STATE_KEYS.include?(key)
            warn "  ⚠️  Unknown condition '#{key}' — ignored"
            return true
          end

          klass.new(@branch, value).satisfied?
        end
      end
    end
  end
end
