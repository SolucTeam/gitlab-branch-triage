# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Conditions
      # date:
      #   attribute: committed_date
      #   condition: older_than | more_recent_than
      #   interval_type: days | weeks | months | years
      #   interval: 60
      class DateCondition < Base
        MULTIPLIERS = {
          "days"   => 1,
          "weeks"  => 7,
          "months" => 30,
          "years"  => 365,
        }.freeze

        def satisfied?
          threshold_days = config["interval"].to_i * MULTIPLIERS.fetch(config["interval_type"] || "days", 1)
          age_days       = branch.days_inactive

          case config["condition"]
          when "older_than"     then age_days >= threshold_days
          when "more_recent_than" then age_days < threshold_days
          else
            warn "Unknown date condition: #{config["condition"]}"
            false
          end
        end
      end
    end
  end
end
