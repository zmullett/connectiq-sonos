using Toybox.Graphics;
using Toybox.WatchUi;

class SonosAuthorizeStartView extends WatchUi.View {

  function initialize() {
    View.initialize();
  }

  function onUpdate(dc) {
    View.onUpdate(dc);
    var plan = BetterTextArea.buildPlan(
      dc,
      loadResource(Rez.Strings.AuthorizeStart),
      Graphics.FONT_MEDIUM);
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    BetterTextArea.render(dc, plan);
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
    WatchUi.switchToView(
      new SonosMessageView(Rez.Strings.AuthorizeCheckPhone),
      null,
      WatchUi.SLIDE_LEFT);
    oAuthHandler_.makeOAuthRequest();
    return true;
  }

  function onAuthorizationResult(communicationSuccess, authorizationSuccess) {
    if (!communicationSuccess) {
      WatchUi.switchToView(
        new SonosMessageView(Rez.Strings.CommunicationError),
        new SonosAuthorizeFailedBehaviorDelegate(authorizationSuccessCallback_),
        WatchUi.SLIDE_LEFT);
    } else if (!authorizationSuccess) {
      WatchUi.switchToView(
        new SonosMessageView(Rez.Strings.AuthorizeFailed),
        new SonosAuthorizeFailedBehaviorDelegate(authorizationSuccessCallback_),
        WatchUi.SLIDE_LEFT);
    } else {
      authorizationSuccessCallback_.invoke();
    }
  }
}

class SonosAuthorizeCheckPhoneView extends WatchUi.View {

  function initialize() {
    View.initialize();
  }

  function onUpdate(dc) {
    View.onUpdate(dc);
    var plan = BetterTextArea.buildPlan(
      dc,
      loadResource(Rez.Strings.AuthorizeCheckPhone),
      Graphics.FONT_MEDIUM);
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    BetterTextArea.render(dc, plan);
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
