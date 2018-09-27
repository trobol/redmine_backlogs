namespace :redmine do
  namespace :backlogs do
    desc "initialize scaled agile settings and trackers"
    task :init_scaled_agile => :environment do
      unless Backlogs.migrated?
        puts "Please run plugin migrations first"
      else
        # enable the feature
        puts "Enabling scaled agile features"
        Backlogs.setting[:scaled_agile_enabled] = true
		
        # Configure the epic and feature trackers
        puts "Creating Epic and Feature trackers"
        epic_trackers = [(Tracker.find_by_name('Epic') || Tracker.create!(:name => 'Epic'))]
        feature_trackers = [(Tracker.find_by_name('Feature') || Tracker.create!(:name => 'Feature'))]
        # get the ids
        epic_trackers = epic_trackers.map { |t| t.id }
        feature_trackers = feature_trackers.map { |t| t.id }
        # set the ids into settings
        Backlogs.setting[:epic_trackers] = epic_trackers
        Backlogs.setting[:feature_trackers] = feature_trackers
        Backlogs.setting[:default_epic_tracker] = epic_trackers[0]
        Backlogs.setting[:default_feature_tracker] = feature_trackers[0]

        #
        puts "Adding trackers to all projects"
        Project.all.each {|p|
          puts "Adding trackers to project #{p}"
          p.update_attribute :tracker_ids, (p.tracker_ids + epic_trackers + feature_trackers).uniq
          p.save!
        }

        puts "Creating boards"
        epic = Tracker.find_by_name('Epic').id
        feature = Tracker.find_by_name('Feature').id
        story = Tracker.find_by_name('Story').id
        task = Tracker.find_by_name('Task').id
        release = '__release'
        sprint = '__sprint'
        team = '__team'
        state = '__state'

        #1.2
        name = "1.2 Establish epics and features"
        unless RbGenericboard.find_by_name(name)
          board = RbGenericboard.new
          board.name = name
          board.col_type = feature
          board.element_type = feature
          board.row_type = epic
          board.save!
          puts "Created board #{board}"
        end

        #1.3
        name = "1.3 Put features in release"
        unless RbGenericboard.find_by_name(name)
          board = RbGenericboard.new
          board.name = name
          board.col_type = release
          board.element_type = feature
          board.row_type = Tracker.find_by_name('Epic').id
          board.save!
          puts "Created board #{board}"
        end

        #2.1
        name = "2.1 Establish stories for features"
        unless RbGenericboard.find_by_name(name)
          board = RbGenericboard.new
          board.name = name
          board.col_type = story
          board.element_type = story
          board.row_type = feature
          board.prefilter = ['__current_release']
          board.save!
          puts "Created board #{board}"
        end

        #2.2
        name = "2.2 Assign stories to teams"
        unless RbGenericboard.find_by_name(name)
          board = RbGenericboard.new
          board.name = name
          board.col_type = team
          board.element_type = story
          board.row_type = feature
          board.prefilter = ['__current_release']
          board.save!
          puts "Created board #{board}"
        end

        #2.3
        name = "2.3 Plan release sprints"
        unless RbGenericboard.find_by_name(name)
          board = RbGenericboard.new
          board.name = name
          board.col_type = sprint
          board.element_type = story
          board.row_type = team
          board.prefilter = ['__current_release', '__my_team']
          board.save!
          puts "Created board #{board}"
        end

         #2.4
        name = "2.4 View release plan by Feature"
        unless RbGenericboard.find_by_name(name)
          board = RbGenericboard.new
          board.name = name
          board.col_type = sprint
          board.element_type = story
          board.row_type = feature
          board.prefilter = ['__current_release']
          board.save!
          puts "Created board #{board}"
        end

        #3.1
        name = "3.1 View selected product backlog"
        unless RbGenericboard.find_by_name(name)
          board = RbGenericboard.new
          board.name = name
          board.col_type = story
          board.element_type = story
          board.row_type = sprint
          board.prefilter = ['__current_sprint', '__my_team']
          board.save!
          puts "Created board #{board}"
        end

        #3.2
        name = "3.2 Manage sprint backlog"
        unless RbGenericboard.find_by_name(name)
          board = RbGenericboard.new
          board.name = name
          board.col_type = state
          board.element_type = task
          board.row_type = story
          board.prefilter = ['__current_sprint', '__my_team']
          board.save!
          puts "Created board #{board}"
        end

        puts "Done configuring scaled agile feature"

      end
    end
  end
end
