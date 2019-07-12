RB.$(function() {
    RB.Factory.initialize(RB.Genericboard, RB.$('#taskboard'));

    /**
     * bind the "Select board" select box
     */
    RB.$('#select_board').change(function(e) {
        document.location.href = RB.urlFor('genericboards', {id: this.value});
    });

    /* make taskbord swimlane header floating */
    RB.$("#board_header").verticalFix({
        delay: 50
    });


});


/***************************************
  GENERICBOARD
***************************************/

RB.Genericboard = RB.Object.create({

  initialize: function(el){
    var j = RB.$(el);
    var self = this; // So we can bind the event handlers to this object

    self.$ = j;
    self.el = el;

    // Associate this object with the element for later retrieval
    j.data('this', self);


    // board configuration data
    self.element_type = j.attr('_element_type');
    self.row_type = j.attr('_row_type');
    self.element_type_name = j.attr('_element_type_name');
    self.row_type_name = j.attr('_row_type_name');
    // Initialize column widths
    self.colWidthUnit = RB.$(".swimlane").width();
    self.defaultColWidth = 0;
    self.loadColWidthPreference();
    self.updateColWidths();
    RB.$("#col_width input").bind('keyup', function(e){if(e.which==13) self.updateColWidths(); });
    RB.$(window).resize(function() {
        if (self.windowresize_update_task) {
            window.clearTimeout(self.windowresize_update_task);
        }
        self.windowresize_update_task = window.setTimeout(function() {
            self.updateColWidths();
            self.windowresize_update_task = null;
        }, 100);
    });
    //initialize mouse handling for drop handling
    j.bind('mousedown.taskboard', function(e) { return self.onMouseDown(e); });
    j.bind('mouseup.taskboard', function(e) { return self.onMouseUp(e); });

    // Initialize task lists, restricting drop to the story
    //var tasks_lists =j.find('.story-swimlane');
    //if (!tasks_lists || !tasks_lists.length) {
    //  alert("There are no task states. Please check the workflow of your tasks tracker in the administration section.");
    //  return;
    //}

    var sortableOpts = {
      placeholder: 'placeholder',
      distance: 3,
      helper: 'clone', //workaround firefox15+ bug where drag-stop triggers click
      start: self.dragStart,
      stop: function(e, ui) {return self.dragStop(e, ui);},
      update: self.dragComplete
      //revert: true, //this interferes with capybara test timings. This braindead stupid jquery-ui issues dragStop after all animations are finished, no way to save the drag result while animation is in progress.
      //scroll: true
    };

    //initialize the cells (td) as sortable
    if (RB.permissions && RB.permissions.update_tasks) {
      j.find('.story-swimlane .list').sortable(RB.$.extend({
        connectWith: '.story-swimlane .list'
        }, sortableOpts));
    }

    sortableOpts = {
      placeholder: 'placeholder',
      distance: 3,
      helper: 'clone', //workaround firefox15+ bug where drag-stop triggers click
      start: function(e, ui){console.log('row drag start');return true;},
      stop: function(e, ui) {console.log('row drop');return true;},
      update: self.dragRowComplete
    };
    //initialize the rows (tr) as sortable
    if (RB.permissions.update_stories) {
      j.find('tbody.row-list').sortable(RB.$.extend({
        }, sortableOpts));
    }

    // Initialize each task in the board
    j.find('.task').each(function(index){
      var task = RB.Factory.initialize(RB.Generic, this, {type_name: self.element_type_name}); // 'this' refers to an element with class="task"
    });
    // Initialize each story in the board
    j.find('.rowelement').each(function(index){
      var task = RB.Factory.initialize(RB.Generic, this, {type_name: self.row_type_name}); // 'this' refers to an element with class="task"
    });

    this.init_add_buttons();

    RB.$('#detail_slider').slider({
        min: 0, max: 2, value: 2,
        change: function(event, ui) {
            self.setDetailLevel(ui.value);
        }
    });

    RB.$('.prefilter-overrides select').change(function(event) {
        console.log('prefilter change', this.value, this.id);
        RB.$(this).parent('form').submit();
    });
  },

  init_add_buttons: function() {
    // add new buttons
    var self = this;
    this.$.find('#generics td').hover(function(e){self.showAddButton(this, e);}, function(e){self.hideAddButton(this, e);});
  },

  onMouseUp: function(e) {
      //re-enable all cells deferred
      setTimeout(function(){
        RB.$(':ui-sortable').sortable('enable');
      }, 10);
  },
  /**
   * can drop when:
   *  RB.constants.task_states.transitions['+c+a ???'][from_state_id][to_state_id] is acceptable
   *
   *  and target story can accept this task:
   *    story and task are same project
   *    or task is in a subproject of story? and redmine cross-project relationships are ok
   */
  onMouseDown: function(e) {
    // find the dragged target
    var el = RB.$(e.target).parents('.model.issue'); // .task or .impediment
    if (!el.length) return; //click elsewhere

    var board = RB.$('#taskboard');
    var col_type = board.attr('_col_type');

    var status_id = el.find('.meta .status_id').text();
    var user_status = el.find('.meta .user_status').text();
    var tracker_id = el.find('.meta .tracker_id').text();
    var old_project_id = el.find('.meta .project_id').text();
    var old_story_id = el.find('.meta .story_id').text();

    //disable non-droppable cells
    if (col_type == '__state') {
        RB.$('td.ui-sortable').each(function() {
          //sharing, NON-restrictive case: only allow any-project relationship

          // check for status
          var new_status_id = this.getAttribute('_col_id');
          // allow dragging to same status to prevent weird behavior
          // if one tries drag into another story but same status.
          if (new_status_id == status_id) { return; }

          if (RB.constants.task_states) {
            var states = RB.constants.task_states['transitions'][tracker_id][user_status][status_id];
            if (!states) { states = RB.constants.task_states['transitions'][tracker_id][user_status][RB.constants.task_states['transitions'][tracker_id][user_status]['default']]; }
            if (RB.$.inArray(String(new_status_id), states) < 0) {
              //workflow does not allow this user to put the issue into this new state.
              RB.$(this).sortable('disable');
              return;
            }
          }

        }); //each
    }

    el = RB.$(e.target).parents('.list'); // .task or .impediment
    if (el && el.length) el.sortable('refresh');
  },

  dragComplete: function(event, ui) {
    if (!ui.sender) { // Handler is triggered for source and target. Thus the need to check.
      ui.item.data('this').saveDragResult();
    }
  },

  dragStart: function(event, ui){
    ui.item.addClass("dragging");
  },

  dragStop: function(event, ui){
    this.onMouseUp(event);
    ui.item.removeClass("dragging");
  },

  dragRowComplete: function(event, ui) {
    if (!ui.sender) { // Handler is triggered for source and target. Thus the need to check.
      ui.item.find('.model.rowelement').first().data('this').saveDragResult();
    }
  },

  showAddButton: function(target, e)  {
    var me = this;
    var btn = RB.$('#add_button_template').children().first().clone();
    RB.$(target).find('.generic_addbtn').append(btn);
    btn.click( function(event) { //this is the button, target is the cell
                    if (event.button > 1) return;
                    var cell = RB.$(event.target).parents("td").first();
                    var row = cell.parents("tr").first();
                    me.newTask(row, cell);
    });
  },

  hideAddButton: function(target, e)  {
    RB.$(target).find('.addbutton').unbind().remove();
  },

  newTask: function(row, cell){
    var type_name, o,
        task = RB.$('#task_template').children().first().clone();
    if (typeof cell.attr('_col_id') == 'undefined') { //we add a row
        type_name = this.row_type_name;
        row.before( RB.$('#row_template').find('tr').first().clone() );
        var new_row = row.prev();
        task = new_row.find('.model.rowelement').first()
    }
    else { // we add an element
        type_name = this.element_type_name;
        cell.find('.generic_addbtn').after(task);
    }

    o = RB.Factory.initialize(RB.Generic, task, {type_name:type_name});
    o.edit();
  },

  loadColWidthPreference: function(){
    var w = RB.UserPreferences.get('taskboardColWidth');
    if (!w) { // 0, null, undefined.
      w = this.defaultColWidth;
      RB.UserPreferences.set('taskboardColWidth', w);
    }
    RB.$("#col_width input").val(w);
  },

  updateColWidths: function(){
    var w = parseInt(RB.$("#col_width input").val(), 10);
    if (!w || isNaN(w)) { // 0,null,undefined,NaN.
      w = this.defaultColWidth;
    }
    RB.$("#col_width input").val(w);
    RB.UserPreferences.set('taskboardColWidth', w);
    if (!w) { //auto width
        var available = RB.$(window).width() -
            self.$('#generics td').first().width(),
            num_cols = self.$('#generics tr').first().children().length - 1;
        w = Math.floor(available / (num_cols * this.colWidthUnit));
        w = Math.max(w, 1);
    }
    self.$(".swimlane").width(this.colWidthUnit * w).css('min-width', this.colWidthUnit * w);
  },

  setDetailLevel: function(level) {
    console.log('setting detail level to', level);
    for (var i=0;i<3;i++) {
        this.el.removeClass('detaillevel-'+i);
    }
    this.el.addClass('detaillevel-'+level);
  }
});
