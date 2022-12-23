using Toybox.Application;
using Toybox.WatchUi;

function createGroupViewAndDelegate() {
  var view = new SonosGroupView();
  var delegate = new SonosGroupViewDelegate(view);
  return {:view => view, :delegate => delegate};
}

class SonosApp extends Application.AppBase {

  function initialize() {
    AppBase.initialize();
    SonosController.SelectedGroup.initialize();
  }

  function getInitialView() {
    if (SonosInterface.isAuthorizationRequired()) {
      return [
        new SonosAuthorizeStartView(),
        new SonosAuthorizeStartBehaviorDelegate(
          new Method(Static, :onAuthorizationSuccess))
      ];
    }
    var groupView = createGroupViewAndDelegate();
    return [groupView[:view], groupView[:delegate]];
  }
  

}

module Static {
  function onAuthorizationSuccess() {
    var groupView = createGroupViewAndDelegate();
    WatchUi.switchToView(
      groupView[:view],
      groupView[:delegate],
     WatchUi.SLIDE_IMMEDIATE);
  }
}