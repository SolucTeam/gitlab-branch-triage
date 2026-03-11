# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Conditions
      # Handles boolean state conditions:
      #   merged: true | false
      #   protected: true | false
      #   has_open_mr: true | false
      class StateCondition < Base
        def self.for(key, branch, value)
          new(branch, key: key, value: value)
        end

        def satisfied?
          expected = config[:value]
          case config[:key]
          when "merged"      then branch.merged?   == expected
          when "protected"   then branch.protected? == expected
          when "has_open_mr" then branch.has_open_mr? == expected
          else
            warn "Unknown state condition: #{config[:key]}"
            false
          end
        end
      end
    end
  end
end
