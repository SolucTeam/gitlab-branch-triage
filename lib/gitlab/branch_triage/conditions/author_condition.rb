# frozen_string_literal: true

module Gitlab
  module BranchTriage
    module Conditions
      # author:
      #   email_domain: "company.com"
      #   name_matches: "^John.*"
      #   username: "john.doe"
      class AuthorCondition < Base
        def satisfied?
          match_author?
        end

        protected

        def match_author?
          if config.key?("email_domain")
            return branch.author_email.end_with?("@#{config["email_domain"]}")
          end
          if config.key?("name_matches")
            return Regexp.new(config["name_matches"]).match?(branch.author_name)
          end
          if config.key?("username")
            term = config["username"]
            return branch.author_email.include?(term) || branch.author_name.include?(term)
          end
          true
        end
      end

      # forbidden_author: — inverse of AuthorCondition
      class ForbiddenAuthor < AuthorCondition
        def satisfied?
          !match_author?
        end
      end
    end
  end
end
