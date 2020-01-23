require 'date'
require 'linear_regression'


class RbRelease < ActiveRecord::Base
  self.table_name = 'releases'

  RELEASE_STATUSES = %w(open closed)
  RELEASE_SHARINGS = %w(none descendants hierarchy tree system)

  unloadable

  belongs_to :project, inverse_of: :releases

  has_many :rb_issue_release, class_name: 'RbIssueRelease', foreign_key: 'release_id', dependent: :delete_all
  has_many :issues_multiple, class_name: 'RbStory', through: :rb_issue_release, source: :issue

  validates_presence_of :project_id, :name
  validates_inclusion_of :status, in: RELEASE_STATUSES
  validates_inclusion_of :sharing, in: RELEASE_SHARINGS
  validates_length_of :name, maximum: 64

  scope :open, -> { where( status: 'open') }
  scope :closed, -> { where(status: 'closed') }
  scope :visible, lambda {|*args| joins(:project).includes(:project).
                                    where(Project.allowed_to_condition(args.first || User.current, :view_releases)) }


  include Backlogs::ActiveRecord::Attributes

  def to_s; name end

  def closed?
    status == 'closed'
  end

  def overdue?
    if release_end_date.present?
      release_end_date < User.current.today && !closed?
    end
  end

  def issues
    issues_multiple
  end

  def stories # compat
    issues
  end

  # Return sprints that contain issues within this release
  def sprints
    RbSprint.where('id in (select distinct(fixed_version_id) from issues inner join rb_issue_releases rbir on issues.id == rbir.issue_id and rbir.release_id=?)', id).order('versions.effective_date')
  end

  # Return sprints closed within this release
  def closed_sprints
    sprints.where("versions.status = ?", "closed")
  end

  def stories_by_sprint
    order = Backlogs.setting[:sprint_sort_order] == 'desc' ? 'DESC' : 'ASC'
    # return issues sorted into sprints. Obviously does not return issues which are not in a sprint
    # unfortunately, group_by returns unsorted results.
    issues.where(tracker_id: RbStory.trackers).joins(:fixed_version).includes(:fixed_version).order("versions.effective_date #{order}").group_by(&:fixed_version_id)
  end

  def has_open_stories?
    stories.open.size > 0
  end

  def has_burndown?
    return false # Never a burndown for a release
  end

  # Returns a string of css classes that apply to the release
  def css_classes
    s = 'release'
    s << ' closed' if closed?
    s << ' overdue' if overdue?
    s
  end

  def remaining_story_points #FIXME merge bohansen_release_chart removed this
    res = 0
    stories.open.each {|s| res += s.story_points if s.story_points}
    res
  end

  def allowed_sharings(user = User.current)
    RELEASE_SHARINGS.select do |s|
      if sharing == s
        true
      else
        case s
        when 'system'
          # Only admin users can set a systemwide sharing
          user.admin?
        when 'hierarchy', 'tree'
          # Only users allowed to manage versions of the root project can
          # set sharing to hierarchy or tree
          project.nil? || user.allowed_to?(:manage_versions, project.root)
        else
          true
        end
      end
    end
  end

  def shared_to_projects(scope_project)
    @shared_projects ||=
      begin
        # Project used when fetching tree sharing
        r = self.project.root? ? self.project : self.project.root
        # Project used for other sharings
        p = self.project
        Project.visible.scoped(include: :releases,
          conditions: ["#{RbRelease.table_name}.id = #{id}" +
          " OR (#{Project.table_name}.status <> #{Project::STATUS_ARCHIVED} AND (" +
          " 'system' = ? " +
          " OR (#{Project.table_name}.lft >= #{r.lft} AND #{Project.table_name}.rgt <= #{r.rgt} AND ? = 'tree')" +
          " OR (#{Project.table_name}.lft > #{p.lft} AND #{Project.table_name}.rgt < #{p.rgt} AND ? IN ('hierarchy', 'descendants'))" +
          " OR (#{Project.table_name}.lft < #{p.lft} AND #{Project.table_name}.rgt > #{p.rgt} AND ? = 'hierarchy')" +
          "))",sharing,sharing,sharing,sharing]).order('lft')
      end
    @shared_projects
  end

  # below methods used to add release notes functionality on release page
  def release_notes_percent_completion(release)
    required_count  = release.issues.release_notes_required.count
    if required_count > 0
      done_count = release.issues.release_notes_done.count
      100 * done_count / required_count
    else
      0
    end
  end

  def release_notes_stats_release
    fixed_issues = (self.issues)
    stats = Hash.new
          stats[:required]     = fixed_issues.release_notes_required.count
          stats[:done]         = fixed_issues.release_notes_done.count
          stats[:done_empty]   = fixed_issues.done_but_release_notes_nil.count
          stats[:todo]         = fixed_issues.release_notes_todo.count
          stats[:not_required] = fixed_issues.release_notes_not_required.count
          stats[:none]         = fixed_issues.release_notes_none.count
          stats[:no_cf]        = fixed_issues.release_notes_no_cf_defined.count
          stats[:invalid]      = fixed_issues.release_notes_invalid.count
          stats[:nil]          = fixed_issues.release_notes_custom_value_nil.count
          stats[:total]        = issues_count
          stats[:completion]   = release_notes_percent_completion(self)

    stats
  end

  # Returns assigned issues count
  def issues_count
    load_issue_counts
    @issue_count
  end
  private

  def load_issue_counts
    unless @issue_count
      @open_issues_count = 0
      @closed_issues_count = 0
      self.issues.group(:status).count.each do |status, count|
        if status.is_closed?
          @closed_issues_count += count
        else
          @open_issues_count += count
        end
      end
      @issue_count = @open_issues_count + @closed_issues_count
    end
  end

end
