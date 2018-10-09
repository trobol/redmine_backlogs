include RbCommonHelper

class FakeProductBacklog
  def id; 0 end
  def name; 'Product Backlog' end
end

class RbEpicboardsController < RbApplicationController
  unloadable

  def show
    cls = RbStory
    product_backlog_stories = cls.product_backlog(@project)
    @product_backlog = { :sprint => FakeProductBacklog.new,
      :type => 'productbacklog', :stories => product_backlog_stories||[] }

    sprints = @project.open_shared_sprints
    @sprint_backlogs = cls.backlogs_by_sprint(@project, sprints)
    @sprint_backlogs.each do |s|
      s[:type] = 'sprint'
    end

    #This project and subprojects
    @epics = RbEpic.where(:project_id => @project).select { |s| RbEpic.trackers.include?(s.tracker_id) }

    @columns = @sprint_backlogs
    @columns.append(@product_backlog)

    respond_to do |format|
      format.html { render :layout => "rb" }
    end
  end

end
