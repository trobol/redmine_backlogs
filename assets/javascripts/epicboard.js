/***************************************
  EPICBOARD
***************************************/

RB.Epicboard = RB.Object.create({

  initialize: function(el){
    var j = RB.$(el);
    var self = this; // So we can bind the event handlers to this object

    self.$ = j;
    self.el = el;

    // Associate this object with the element for later retrieval
    j.data('this', self);

    //initialize mouse handling for drop handling
    /*j.bind('mousedown.epicboard', function(e) { return self.onMouseDown(e); });
    j.bind('mouseup.epicboard', function(e) { return self.onMouseUp(e); });*/

    // Initialize epic lists, restricting drop to the story
    var epics_lists =j.find('.story-swimlane');

    var sortableOpts = {
      placeholder: 'placeholder',
      distance: 3,
      helper: 'clone', //workaround firefox15+ bug where drag-stop triggers click
      start: self.dragStart,
      stop: self.dragStop,
      update: self.dragComplete
    };

    epics_lists.each(function(index){
      var id = '#' + RB.$(this).attr('id') + ' .list';

      j.find(id).sortable(RB.$.extend({
        connectWith: id
        }, sortableOpts));
    });
    // Initialize unassigned stories list
    j.find(".list").sortable(RB.$.extend({
      connectWith: '.list'
    }, sortableOpts));

    // Initialize each story in the board
    j.find('.story').each(function(index){
      RB.Factory.initialize(RB.StoryEB, this); // 'this' refers to an element with class="story"
    });
    j.find('.epic').each(function(index){
      RB.Factory.initialize(RB.EpicEB, this); // 'this' refers to an element with class="story"
    });

    // Add handler for .add_new click
    j.find('#board_header .add_new').bind('click', self.handleAddNewEpicClick);
    j.find('#stories .add_new').bind('click', self.handleAddNewStoryClick);

  },

  /*onMouseUp: function(e) {
      //re-enable all cells deferred
      setTimeout(function(){
        RB.$(':ui-sortable').sortable('enable');
      }, 10);
  },

  onMouseDown: function(e) {
  },*/

  dragComplete: function(event, ui) {
    var isDropTarget = (ui.sender==null); // Handler is triggered for source and target. Thus the need to check.

    if(isDropTarget){
      ui.item.data('this').saveDragResult();
    }
  },

  dragStart: function(event, ui){
    ui.item.addClass("dragging");
  },

  dragStop: function(event, ui){
    ui.item.removeClass("dragging");
  },

  handleAddNewStoryClick: function(event){
    if (event.button > 1) return;
    var row = RB.$(this).parents("tr").first();
    RB.$('#epicboard').data('this').newStory(row);
  },

  handleAddNewEpicClick: function(event){
    if (event.button > 1) return;
    RB.$('#epicboard').data('this').newEpic();
  },

  newStory: function(row){
    var story = RB.$('#story_template').children().first().clone();
    row.find(".list").first().prepend(story);
    var o = RB.Factory.initialize(RB.StoryEB, story);
    o.edit();
  },

  newEpic: function(){
    var epic = RB.$('#epic_template').children().first().clone();
    RB.$("#stories").prepend('<tr class="epic-swimlame"><td></td><td class="swimlane list ui-sortable"></td></tr>');
    RB.$("#stories tr:first td:first").prepend(epic);
    var o = RB.Factory.initialize(RB.EpicEB, epic);
    o.edit();
  }
});

RB.UserFilter = RB.Object.create({
  initialize: function() {
    var me = this,
      _ = RB.constants.locale._;
    me.el = RB.$(".userfilter");
    me.el.multiselect({
      selectedText: _("Filter epics"),
      noneSelectedText: _("Filter epics: my epics"),
      checkAllText: _("All epics"),
      uncheckAllText: _("My epics"),
      checkAll: function() { me.updateUI(); },
      uncheckAll: function() { me.onUnCheckAll(); },
      click: function() { me.updateUI(); }
    });
    me.el.multiselect('checkAll');
  },

  /* uncheck all users but check the current user, so we get a private mode button */
  onUnCheckAll: function() {
    var uid = RB.$("#userid").text();
    this.el.multiselect("widget").find(":checkbox[value='"+uid+"']").each(function() {this.checked = true;} );
    this.updateUI();
  },

  updateUI: function() {
    this.updateEpics();
    this.updateStories();
  },

  updateEpics: function() {
    var me = this;
    RB.$(".epic").each(function() {
      var epic_ownerid = null;
      try{
        epic_ownerid = RB.$(".assigned_to_id .v", this).text();
      } catch(e){ return; }
      if (!epic_ownerid || me.el.multiselect("widget").find(":checkbox[value='"+epic_ownerid+"']").is(':checked')) {
        RB.$(this).show();
      }else {
        RB.$(this).hide();
      }
    });
  },

  updateStories: function() {
    //Check if all stories should be visible even if not used
    var showUnusedStories = this.el.multiselect("widget").find(":checkbox[value='s']").is(':checked');

    //Parse through all the stories and hide the ones not used
    RB.$('.story').each(function() {
      console.log('Epicboard::updateStories parsing story', this);
      var sprintInfo = RB.$(this).children('.id').children('a')[0];
      var storyID = sprintInfo.innerHTML;

      RB.$(this).closest('tr').show();
      var hasVisEpics = 0;
      var hasEpics = 0;  // Keep track if a story has epics (visible or not)

      //Parse each epic in the story and see if any epics are not hidden
      RB.$("#epics [id^="+storyID+"_]").each(function(){
        RB.$(this).children().each(function(){
          hasEpics = 1;
          if (RB.$(this).is(':visible'))
            hasVisEpics = 1;
        });
      });

      //Hide or show story row based on if any epics are visible
      if (hasVisEpics || (showUnusedStories && !hasEpics))
        RB.$(this).closest('tr').show();
      else
        RB.$(this).closest('tr').hide();
    });
   }
});

RB.$(function(){ /*document ready*/
  RB.$("#board_header").verticalFix({
    delay: 50
  });
  RB.UserFilter.initialize();
});

