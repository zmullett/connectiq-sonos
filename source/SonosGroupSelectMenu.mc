using Toybox.WatchUi;

class SonosGroupSelectMenuBuilderDelegate
    extends WatchUi.BehaviorDelegate {
  var groups_;
  var numPendingHouseholds_;
  var onCommunicationError_;

  function initialize() {
    BehaviorDelegate.initialize();
  }

  function startDiscovery() {
    SonosController.getHouseholds(method(:onGetHouseholdsResponse));
  }

  private function notifyError(error) {
    WatchUi.switchToView(
      new SonosMessageView(error[:message]),
      null,
      WatchUi.SLIDE_IMMEDIATE);
  }

  function onGetHouseholdsResponse(error, householdIds) {
    if (error != null) {
      notifyError(error);
      return;
    }
    groups_ = [];
    numPendingHouseholds_ = householdIds.size();
    presentMenuIfDiscoveryComplete();
    for (var i=0; i < householdIds.size(); i++) {
      SonosController.getGroups(
        householdIds[i],
        method(:onGetGroupsResponse));
    }
  }

  function onGetGroupsResponse(error, householdId, groups) {
    if (error != null) {
      notifyError(error);
      return;
    }
    groups_.addAll(groups);
    numPendingHouseholds_--;
    presentMenuIfDiscoveryComplete();
  }

  private function presentMenuIfDiscoveryComplete() {
    if (numPendingHouseholds_ == 0) {
      presentMenu();
    }
  }

  private function presentMenu() {
  	WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    WatchUi.pushView(
      new SonosGroupSelectMenuView(groups_),
      new SonosGroupSelectMenuDelegate(),
      WatchUi.SLIDE_IMMEDIATE);
  }
}

class SonosGroupSelectMenuView extends WatchUi.Menu2 {
  function initialize(groups) {
    WatchUi.Menu2.initialize(
      {:title=>WatchUi.loadResource(Rez.Strings.MenuTitle)});
    for (var i = 0; i < groups.size(); i++) {
      self.addItem(new WatchUi.MenuItem(
        groups[i][:name_], null, groups[i], {}));
    }
    self.addItem(new WatchUi.MenuItem(
      WatchUi.loadResource(Rez.Strings.Unauthorize),
      null,
      MENU_ITEM_UNAUTHORIZE,
      {}));
  }
}

class SonosGroupSelectMenuDelegate extends WatchUi.Menu2InputDelegate {

  function initialize() {
    Menu2InputDelegate.initialize();
  }

  function onSelect(item) {
    if (item.getId().equals(MENU_ITEM_UNAUTHORIZE)) {
      SonosInterface.removeAuthorization();
      SonosController.SelectedGroup.clear();
      onDone();
      WatchUi.switchToView(
        new SonosAuthorizeStartView(),
        new SonosAuthorizeStartBehaviorDelegate(
          new Method(Static, :onAuthorizationSuccess)),
        WatchUi.SLIDE_IMMEDIATE);
    } else {
      var group = item.getId();
      SonosController.SelectedGroup.set(group[:id], group[:name_]);
      onDone();
    }
  }
}