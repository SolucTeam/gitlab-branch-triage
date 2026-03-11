# frozen_string_literal: true

require "httparty"
require "active_support"
require "active_support/core_ext/numeric/time"
require "active_support/core_ext/time/calculations"
require "yaml"
require "logger"
require "optparse"

module Gitlab
  module BranchTriage
    autoload :VERSION,            "gitlab/branch_triage/version"
    autoload :Client,             "gitlab/branch_triage/client"
    autoload :Runner,             "gitlab/branch_triage/runner"
    autoload :PolicyLoader,       "gitlab/branch_triage/policy_loader"
    autoload :GroupResolver,      "gitlab/branch_triage/group_resolver"
    autoload :UserResolver,       "gitlab/branch_triage/user_resolver"

    module Resource
      autoload :Branch,           "gitlab/branch_triage/resource/branch"
      autoload :MergeRequest,     "gitlab/branch_triage/resource/merge_request"
    end

    module Conditions
      autoload :Base,             "gitlab/branch_triage/conditions/base"
      autoload :DateCondition,    "gitlab/branch_triage/conditions/date_condition"
      autoload :InactiveDays,     "gitlab/branch_triage/conditions/inactive_days"
      autoload :NameCondition,    "gitlab/branch_triage/conditions/name_condition"
      autoload :ForbiddenName,    "gitlab/branch_triage/conditions/name_condition"
      autoload :StateCondition,   "gitlab/branch_triage/conditions/state_condition"
      autoload :AuthorCondition,  "gitlab/branch_triage/conditions/author_condition"
      autoload :ForbiddenAuthor,  "gitlab/branch_triage/conditions/author_condition"
      autoload :Evaluator,        "gitlab/branch_triage/conditions/evaluator"
      autoload :MrEvaluator,      "gitlab/branch_triage/conditions/mr_conditions"
      autoload :MrDateCondition,  "gitlab/branch_triage/conditions/mr_conditions"
      autoload :MrDraft,          "gitlab/branch_triage/conditions/mr_conditions"
      autoload :MrAssigned,       "gitlab/branch_triage/conditions/mr_conditions"
      autoload :MrHasReviewer,    "gitlab/branch_triage/conditions/mr_conditions"
      autoload :MrPipelineStatus, "gitlab/branch_triage/conditions/mr_conditions"
      autoload :MrLabels,         "gitlab/branch_triage/conditions/mr_conditions"
      autoload :MrForbiddenLabels,"gitlab/branch_triage/conditions/mr_conditions"
      autoload :MrTargetBranch,   "gitlab/branch_triage/conditions/mr_conditions"
    end

    module Actions
      autoload :Base,             "gitlab/branch_triage/actions/base"
      autoload :Notify,           "gitlab/branch_triage/actions/notify"
      autoload :Delete,           "gitlab/branch_triage/actions/delete"
      autoload :Print,            "gitlab/branch_triage/actions/print"
      autoload :Comment,          "gitlab/branch_triage/actions/comment"
      autoload :Executor,         "gitlab/branch_triage/actions/executor"
      autoload :CommentMr,        "gitlab/branch_triage/actions/mr_actions"
      autoload :CloseMr,          "gitlab/branch_triage/actions/mr_actions"
      autoload :LabelMr,          "gitlab/branch_triage/actions/mr_actions"
      autoload :NotifyMr,         "gitlab/branch_triage/actions/mr_actions"
      autoload :MrExecutor,       "gitlab/branch_triage/actions/mr_actions"
    end
  end
end
