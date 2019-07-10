class RbStory < RbGeneric
  unloadable

  private

  def self.tracker_setting; :story_trackers end

  def self.__find_options_normalize_option(option)
    option = [option] if option && !option.is_a?(Array)
    option = option.collect{|s| s.is_a?(Integer) ? s : s.id} if option
  end

  def self.__find_options_add_permissions(options)
    permission = options.delete(:permission)
    permission = false if permission.nil?

    options[:conditions] ||= []
    if permission
      if Issue.respond_to? :visible_condition
        visible = Issue.visible_condition(User.current, :project => project || Project.find(project_id))
      else
        visible = Project.allowed_to_condition(User.current, :view_issues)
      end
      Backlogs::ActiveRecord.add_condition(options, visible)
    end
  end

  def self.__find_options_sprint_condition(project_id, sprint_ids)
    if Backlogs.settings[:sharing_enabled]
      ["
        tracker_id in (?)
        and fixed_version_id IN (?)", self.trackers, sprint_ids]
    else
      ["
        issues.project_id = ?
        and tracker_id in (?)
        and fixed_version_id IN (?)", project_id, self.trackers, sprint_ids]
    end
  end

  def self.__find_options_pbl_condition(project_id)
    ["
      issues.project_id in (#{Project.find(project_id).projects_in_shared_product_backlog.map{|p| p.id}.join(',')})
      and tracker_id in (?)
      and fixed_version_id is NULL
      and is_closed = ?", self.trackers, false]
  end

  public

  def self.class_default_status
    begin
      RbStory.trackers(:trackers)[0].default_status
    rescue
      Rails.logger.error("Story has no trackers configured")
      nil
    end
  end

  def self.inject_lower_higher
    prev = nil
    all.map {|story|
      #optimization: set virtual attributes to avoid hundreds of sql queries
      # this requires that the scope is clean - meaning exactly ONE backlog is queried here.
      prev.higher_item = story if prev
      story.lower_item = prev
      prev = story
    }
  end

  def self.backlog(project_id, sprint_id, options={})
    options = options.merge({
      :project => project_id,
      :sprint => sprint_id,
    })

    Rails.logger.info "The options: #{options}."
    self.visible.
      order("#{self.table_name}.position").
      backlog_scope(options)
  end

  def self.product_backlog(project, limit=nil)
    return RbStory.backlog(project.id, nil, {:limit => limit })
  end

  def self.sprint_backlog(sprint, options={})
    return RbStory.backlog(sprint.project.id, sprint.id, options)
  end

  def self.release_backlog(release, options={})
    options = options.merge({
      :project => release.project.id,
    })

    Rails.logger.info "The options: #{options}."
    self.visible.
      joins("INNER JOIN rb_issue_releases ON rb_issue_releases.issue_id = issues.id AND rb_issue_releases.release_id = #{release.id}").
      order("#{self.table_name}.position").
      backlog_scope(options)
  end

  def self.backlogs_by_sprint(project, sprints, options={})
    #make separate queries for each sprint to get higher/lower item right
    return [] unless sprints
    sprints.map do |s|
      { :sprint => s,
        :stories => RbStory.backlog(project.id, s.id, options)
      }
    end
  end

  def self.backlogs_by_release(project, releases, options={})
    #make separate queries for each release to get higher/lower item right
    return [] unless releases
    releases.map do |r|
      { :release => r,
        :stories => RbStory.release_backlog(r, options)
      }
    end
  end


  def self.create_and_position(params)
    params['prev'] = params.delete('prev_id') if params.include?('prev_id')
    params['next'] = params.delete('next_id') if params.include?('next_id')
    params['prev'] = nil if (['next', 'prev'] - params.keys).size == 2

    # lft and rgt fields are handled by acts_as_nested_set
    attribs = params.select{|k,_v| !['prev', 'next', 'id', 'lft', 'rgt'].include?(k) && RbStory.column_names.include?(k) }

    attribs[:status] = RbStory.class_default_status
    attribs = Hash[*attribs.flatten]
    s = RbStory.new(attribs)
    s.save!
    s.update_and_position!(params)

    return s
  end

  scope :updated_since, lambda {|since|
          where(["#{self.table_name}.updated_on > ?", Time.parse(since)]).
          order("#{self.table_name}.updated_on ASC")
        }

  def self.find_all_updated_since(since, project_id)
    #look in backlog and sprint. look in shared sprints
    project = Project.select("id,lft,rgt,parent_id,name").find(project_id)
    sprints = project.open_shared_sprints.map{|s|s.id}
    #following will execute 3 queries and join it as array
    self.backlog_scope( {:project => project_id, :sprint => nil, :release => nil } ).
          updated_since(since) |
      self.backlog_scope( {:project => project_id, :sprint => sprints, :release => nil } ).
          updated_since(since)
  end

  alias :trackers :story_trackers
  
  def self.trackers(options = {})
    self.story_trackers(options)
  end

  def self.trackers_include?(tracker_id)
    tracker_ids = Backlogs.setting[tracker_setting] || []
    tracker_ids = tracker_ids.map(&:to_i)
    tracker_ids.include?(tracker_id.to_i)
  end

  def tasks
    return self.children
  end

  def set_points(p)
    return self.journalized_update_attribute(:story_points, nil) if p.blank? || p == '-'

    return self.journalized_update_attribute(:story_points, 0) if p.downcase == 's'

    if Backlogs.setting[:story_points_are_integer]
      return self.journalized_update_attribute(:story_points, Integer(p)) if Integer(p) >= 0
    else
      return self.journalized_update_attribute(:story_points, Float(p)) if Float(p) >= 0
    end
  end

  def update_and_position!(params)
    params['prev'] = params.delete('prev_id') if params.include?('prev_id')
    params['next'] = params.delete('next_id') if params.include?('next_id')

    self.position!(params)

    # lft and rgt fields are handled by acts_as_nested_set
    if Issue.const_defined? "SAFE_ATTRIBUTES"
      safe_attributes_names = RbStory::SAFE_ATTRIBUTES
    else
      safe_attributes_names = Issue.new(
        :project_id=>params[:project_id] # required to verify "safeness"
      ).safe_attribute_names
    end
    attribs = params.select{|k,_v| !['prev', 'id', 'project_id', 'lft', 'rgt'].include?(k) && safe_attributes_names.include?(k) }
    attribs = Hash[*attribs.flatten]

    return self.journalized_update_attributes attribs
  end

  def position!(params)
    if params.include?('prev')
      if params['prev'].blank?
        self.move_to_top # move after 'prev'. Meaning no prev, we go at top
      else
        self.move_after(RbStory.find(params['prev']))
      end
    elsif params.include?('next')
      if params['next'].blank?
        self.move_to_bottom
      else
        self.move_before(RbStory.find(params['next']))
      end
    end
  end

  # Definition of a continued story:
  # * "Copied to" relation with another story
  # * The other story is in same release
  # * The other story is rejected
  def continued_story?
    self.relations.each{|r|
      if r.relation_type == IssueRelation::TYPE_COPIED_TO
        from_story = RbStory.find(r.issue_from_id)
        if from_story.status.backlog_is?(:failure, RbStory.trackers(:trackers)[0])
#FIXME check from_story is in the same release as this story at the
# point in time being examined.
          return true
        end
      end
    }
    return false
  end

  def burndown(sprint = nil, status=nil)
    return nil unless self.is_story?
    sprint ||= self.fixed_version.becomes(RbSprint) if self.fixed_version
    return nil if sprint.nil? || !sprint.has_burndown?

    bd = {:points_committed => [], :points_accepted => [], :points_resolved => [], :hours_remaining => []}

    self.history.filter(sprint, status).each{|d|
      if d.nil? || d[:sprint] != sprint.id || d[:tracker] != :story
        [:points_committed, :points_accepted, :points_resolved, :hours_remaining].each{|k| bd[k] << nil}
      else
        bd[:points_committed] << d[:story_points]
        bd[:points_accepted] << (d[:status_success] ? d[:story_points] : 0)
        bd[:points_resolved] << (d[:status_success] || d[:hours].to_f == 0.0 ? d[:story_points] : 0)
        bd[:hours_remaining] << (d[:status_closed] ? 0 : d[:hours])
      end
    }
    return bd
  end

  def story_follow_task_state
    return if Backlogs.setting[:story_follow_task_status] != 'close' && Backlogs.setting[:story_follow_task_status] != 'loose'
    return if self.status.is_closed? #bail out if we are closed

    self.reload #we might be stale at this point
    case Backlogs.setting[:story_follow_task_status]
      when 'close'
        set_closed_status_if_following_to_close
      when 'loose'
        avg_ratio = tasks.map{|task| task.status.default_done_ratio.to_f }.sum / tasks.length # #837 coerce to float, nil counts for 0.0
        #find status near avg_ratio
        #find the status allowed, order by position, with nearest default_done_ratio not higher then avg_ratio
        new_st = nil
        self.new_statuses_allowed_to.each{|status|
          new_st = status if status.default_done_ratio.to_f <= avg_ratio # #837 use to_f for comparison of number OR nil
          break if status.default_done_ratio.to_f > avg_ratio
        }
        #set status and good.
        self.journalized_update_attributes :status_id => new_st.id if new_st
        set_closed_status_if_following_to_close

        #calculate done_ratio weighted from tasks
        recalculate_attributes_for(self.id) unless Issue.use_status_for_done_ratio?
      else

    end
  end

  def set_closed_status_if_following_to_close
        status_id = Backlogs.setting[:story_close_status_id]
        unless status_id.nil? || status_id.to_i == 0
          # bail out if something is other than closed.
          tasks.each{|task|
            return unless task.status.is_closed?
          }
          self.journalized_update_attributes :status_id => status_id.to_i #update, but no need to position
        end
  end

  def descendants(*args)
    descendants = super
    descendants.each do |issue|
      next unless issue.is_task?
      if self.id == (issue.parent_id || issue.parent_issue_id)
        issue.instance_variable_set(:@rb_story, self)
      end
    end
    descendants
  end

end
