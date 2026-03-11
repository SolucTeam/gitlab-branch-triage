# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Conditions
      class Base
        attr_reader :branch, :config

        def initialize(branch, config)
          @branch = branch
          @config = config
        end

        # Subclasses must implement #satisfied?
        def satisfied?
          raise NotImplementedError, "#{self.class}#satisfied? not implemented"
        end
      end
    end
  end
end
