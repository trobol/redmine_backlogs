class RbReleaseMultiview < ActiveRecord::Base
  self.table_name = 'rb_releases_multiview'

  unloadable

  belongs_to :project

  serialize :release_ids

  validates_presence_of :project_id, :name

  include Backlogs::ActiveRecord::Attributes

  def releases
    RbRelease.where(id: self.release_ids)
            .order("release_end_date ASC").all
  end

  def has_burnchart?
    false #FIXME release burndown broken
    #releases.inject(false) {|result,release| result |= release.has_burndown?}
  end

  def burnchart
    return nil #FIXME release burndown broken
    #return nil unless self.has_burnchart?
    #@cached_burnchart ||= RbReleaseMultiviewBurnchart.new(self)
    #return @cached_burnchart
  end

end
