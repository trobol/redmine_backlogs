class RbRefineStoriesController < ApplicationController
  menu_item :issues
  
  include ProjectsHelper
  include QueriesHelper
  helper :queries
  helper :issues
  before_filter :load_project, :get_query

  def index
    @query = get_query
    @issue_count = @query.issue_count
    @issues = @query.issues
    @statuses = IssueStatus.find(Backlogs.setting[:status_for_validating])
  end

  private
    def load_project
      @project = Project.find(params[:project_id])
    end

    def get_query
      query = IssueQuery.new(name: "refinement", filters: {"status_id"=>{:operator=>"=", :values=>Backlogs.setting[:status_for_validating]}}, group_by: "assigned_to")
      query.project_id = @project.id
      query
    end
end
