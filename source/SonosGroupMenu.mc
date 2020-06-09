using Toybox.WatchUi;

class SonosGroupMenuBuilderDelegate extends WatchUi.BehaviorDelegate {
  var groups_;
  var numPendingHouseholds_;
  var selectedGroupListener_;
  var onCommunicationError_;

  function initialize(selectedGroupListener) {
    BehaviorDelegate.initialize();
    selectedGroupListener_ = selectedGroupListener;
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
    var menu = new WatchUi.Menu2({
      :title=>WatchUi.loadResource(Rez.Strings.MenuTitle)});
    for (var i = 0; i < groups_.size(); i++) {
      menu.addItem(new WatchUi.MenuItem(
        groups_[i][:name], null, groups_[i], {}));
    }
    menu.addItem(new WatchUi.MenuItem(
      WatchUi.loadResource(Rez.Strings.Unauthorize),
      null,
      MENU_ITEM_UNAUTHORIZE,
      {}));
    WatchUi.switchToView(
      menu,
      new SonosGroupMenuDelegate(selectedGroupListener_),
      WatchUi.SLIDE_IMMEDIATE);
  }
}

class SonosGroupMenuDelegate extends WatchUi.Menu2InputDelegate {
  var selectedGroupListener_;

  function initialize(selectedGroupListener) {
    Menu2InputDelegate.initialize();
    selectedGroupListener_ = selectedGroupListener;
  }

  function onSelect(item) {
    if (item.getId() == MENU_ITEM_UNAUTHORIZE) {
      SonosInterface.removeAuthorization();
      selectedGroupListener_.clear();
      WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
      WatchUi.switchToView(
        new SonosAuthorizeStartView(),
        new SonosAuthorizeStartBehaviorDelegate(
          method(:onAuthorizationSuccess)),
        WatchUi.SLIDE_IMMEDIATE);
    } else {
      var group = item.getId();
      selectedGroupListener_.set(group[:id], group[:name]);
      WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
  }
}