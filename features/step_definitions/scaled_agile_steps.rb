Given(/^scaled agile features are enabled and configured$/) do
  Backlogs.setting[:scaled_agile_enabled] = true

  defaultstatus = IssueStatus.find_by(name: 'New')
  # Configure the epic and feature trackers
  epic_trackers = [(Tracker.find_by_name('Epic') || Tracker.create!(name: 'Epic', default_status: defaultstatus))]
  feature_trackers = [(Tracker.find_by_name('Feature') || Tracker.create!(name: 'Feature', default_status: defaultstatus))]
  # get the ids
  epic_trackers = epic_trackers.map { |t| t.id }
  feature_trackers = feature_trackers.map { |t| t.id }
  # set the ids into settings
  Backlogs.setting[:epic_trackers] = epic_trackers
  Backlogs.setting[:feature_trackers] = feature_trackers
  Backlogs.setting[:default_epic_tracker] = epic_trackers[0]
  Backlogs.setting[:default_feature_tracker] = feature_trackers[0]
  #enable the trackers in project
  @project.update_attribute :tracker_ids, (@project.tracker_ids + epic_trackers + feature_trackers)

end
Given (/^I am member of some teams$/) do
  #define some teams
  team = Group.new
  team.name = 'Team 1'
  team.save!
  team.users << [@user]
end

Given(/^some default generic boards are configured$/) do
  epic = Tracker.find_by_name('Epic').id
  feature = Tracker.find_by_name('Feature').id
  story = Tracker.find_by_name('Story').id
  task = Tracker.find_by_name('Task').id
  release = '__release'
  sprint = '__sprint'
  team = '__team'
  state = '__state'

  #1.2
  board = RbGenericboard.new
  board.name = "1.2 Establish epics and features"
  board.col_type = feature
  board.element_type = feature
  board.row_type = epic
  board.save!

  #1.3
  board = RbGenericboard.new
  board.name = "1.3 Put features in release"
  board.col_type = release
  board.element_type = feature
  board.row_type = Tracker.find_by_name('Epic').id
  board.save!

  #2.1
  board = RbGenericboard.new
  board.name = "2.1 Establish stories for features"
  board.col_type = story
  board.element_type = story
  board.row_type = feature
  board.prefilter = ['__current_release']
  board.save!

  #2.2
  board = RbGenericboard.new
  board.name = "2.2 Assign stories to teams"
  board.col_type = team
  board.element_type = story
  board.row_type = feature
  board.prefilter = ['__current_release']
  board.save!

  #2.3
  board = RbGenericboard.new
  board.name = "2.3 Plan release sprints"
  board.col_type = sprint
  board.element_type = story
  board.row_type = team
  board.prefilter = ['__current_release', '__my_team']
  board.colfilter = ['__current_release']
  board.include_none_in_cols = "1"
  board.save!

  #2.4
  board = RbGenericboard.new
  board.name = "2.4 View release plan by Ffature"
  board.col_type = sprint
  board.element_type = story
  board.row_type = feature
  board.prefilter = ['__current_release']
  board.save!

  #3.1
  board = RbGenericboard.new
  board.name = "3.1 View selected product backlog"
  board.col_type = story
  board.element_type = story
  board.row_type = sprint
  board.prefilter = ['__current_sprint', '__my_team']
  board.save!

  #3.2
  board = RbGenericboard.new
  board.name = "3.2 Manage sprint backlog"
  board.col_type = state
  board.element_type = task
  board.row_type = story
  board.prefilter = ['__current_sprint', '__my_team']
  board.save!
end

Given(/^I am viewing the boards page$/) do
  first_genericboard_id = RbGenericboard.order(:name).first.id
  visit url_for(controller: :projects, action: :show, id: @project.identifier, only_path: true)
  verify_request_status(200)
  click_link("Boards")
  page.current_path.should == url_for(controller: :rb_genericboards, action: :show, genericboard_id: first_genericboard_id, project_id: @project.identifier, only_path: true)
  verify_request_status(200)
end

Then(/^the scaled agile tracker fields should be set to their correct trackers$/) do
    field = find_field('settings[epic_trackers][]')
    field.value.should == ["#{Tracker.find_by_name('Epic').id}"]

    field = find_field('settings[feature_trackers][]')
    field.value.should == ["#{Tracker.find_by_name('Feature').id}"]

    field = find_field('settings[default_epic_tracker]')
    field.value.should == "#{Tracker.find_by_name('Epic').id}"

    field = find_field('settings[default_feature_tracker]')
    field.value.should == "#{Tracker.find_by_name('Feature').id}"
end

Then(/^the boards should provide correct data for rows, columns and elements$/) do
  boards = RbGenericboard.all
  boards.length.should == 8
  n = 0
  puts "Checking board #{boards[n]}"
  b = boards[n]
  b.element_type_name.should == 'Feature'
  b.row_type_name.should == 'Epic'
  b.col_type_name.should == 'Feature'
  #puts "prefilter name #{b.prefilter_name}"
  b.prefilter_name.should == ''
  #puts b.col_object(id)
  #puts b.row_object(id)
  columns = b.columns(@project)
  #puts "columns #{columns}"
  columns.length.should == 1
  columns[0].is_a?(RbGeneric).should be true
  #puts "rows #{b.rows(@project).to_a}"
  #puts b.elements(@project).to_a
  #puts "elements by cell #{b.elements_by_cell(@project)}"
  puts b.elements_by_cell(@project).length
  #puts "prefilter objects #{b.prefilter_objects(@project)}"
  b.prefilter_objects(@project).length.should == 0
  #puts "FIXME Todo..."

  n = 2
  puts "Checking board #{boards[n]}"
  b = boards[n]
  b.name.should == "2.1 Establish stories for features"
  #puts "prefilter objects #{b.prefilter_objects(@project)}"
  f = b.prefilter_objects(@project)
  f.length.should == 1
  f['__current_release'].is_a?(RbRelease).should be true
  f['__current_release'].name.should == 'Rel 1'
  puts b.elements(@project).to_a


  n = 4
  puts "Checking board #{boards[n]}"
  b = boards[n]
  b.name.should == "2.3 Plan release sprints"
  f = b.prefilter_objects(@project)
  puts "prefilter objects #{f}"
  f.length.should == 2
  f['__current_release'].is_a?(RbRelease).should be true
  f['__current_release'].name.should == 'Rel 1'
  f['__my_team'].is_a?(Group).should be true
  f['__my_team'].lastname.should == 'Team 1'

  columns = b.columns(@project)
  puts "columns #{columns}"
  #columns.each {|c| puts("col #{c}") }
  page.driver.render('/tmp/2.3.png', full: true)

  columns.length.should == 3
  columns[0].is_a?(RbFakeGeneric).should be true
  columns[1].is_a?(RbSprint).should be true
  columns[2].is_a?(RbSprint).should be true

  puts b.elements(@project).to_a

end
