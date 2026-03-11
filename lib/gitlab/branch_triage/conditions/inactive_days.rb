# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Conditions
      # Shorthand: inactive_days: 60
      class InactiveDays < Base
        def satisfied?
          branch.days_inactive >= config.to_i
        end
      end
    end
  end
end
