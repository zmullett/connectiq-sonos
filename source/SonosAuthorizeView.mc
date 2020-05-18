using Toybox.WatchUi;

class SonosAuthorizeStartView extends WatchUi.View {

  function initialize() {
    View.initialize();
  }

  function onLayout(dc) {
    setLayout(Rez.Layouts.AuthorizeStart(dc));
  }
}

class SonosAuthorizeStartBehaviorDelegate extends WatchUi.BehaviorDelegate {
  var authorizationSuccessCallback_;
  var oAuthHandler_;

  function initialize(authorizationSuccessCallback) {
    BehaviorDelegate.initialize();
    authorizationSuccessCallback_ = authorizationSuccessCallback;
    oAuthHandler_ = SonosInterface.createOAuthHandler(method(:onAuthorizationResult));
    oAuthHandler_.registerForOAuthMessages();
  }

  function onSelect() {
    WatchUi.switchToView(new SonosAuthorizeCheckPhoneView(), null, WatchUi.SLIDE_LEFT);
    oAuthHandler_.makeOAuthRequest();
    return true;
  }

  function onAuthorizationResult(communicationSuccess, authorizationSuccess) {
    if (!communicationSuccess) {
      WatchUi.switchToView(
        new SonosCommunicationErrorView(),
        new SonosAuthorizeFailedBehaviorDelegate(authorizationSuccessCallback_),
        WatchUi.SLIDE_RIGHT);
    } else if (!authorizationSuccess) {
      WatchUi.switchToView(
        new SonosAuthorizeFailedView(),
        new SonosAuthorizeFailedBehaviorDelegate(authorizationSuccessCallback_),
        WatchUi.SLIDE_RIGHT);
    } else {
      authorizationSuccessCallback_.invoke();
    }
  }
}

class SonosAuthorizeCheckPhoneView extends WatchUi.View {

  function initialize() {
    View.initialize();
  }

  function onLayout(dc) {
    setLayout(Rez.Layouts.AuthorizeCheckPhone(dc));
  }
}

class SonosAuthorizeFailedView extends WatchUi.View {

  function initialize() {
    View.initialize();
  }

  function onLayout(dc) {
    setLayout(Rez.Layouts.AuthorizeFailed(dc));
  }
}

class SonosAuthorizeFailedBehaviorDelegate extends WatchUi.BehaviorDelegate {
  var authorizationSuccessCallback_;

  function initialize(authorizationSuccessCallback) {
    BehaviorDelegate.initialize();
    authorizationSuccessCallback_ = authorizationSuccessCallback;
  }

  function onBack() {
    WatchUi.switchToView(
      new SonosAuthorizeStartView(),
      new SonosAuthorizeStartBehaviorDelegate(authorizationSuccessCallback_),
      WatchUi.SLIDE_RIGHT);
    return true;
  }
}
