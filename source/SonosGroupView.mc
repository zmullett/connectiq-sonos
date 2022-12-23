using Toybox.Graphics;
using Toybox.Timer;
using Toybox.WatchUi;

function drawCenteredLabelAndIcon(dc, label, iconResource) {
  var plan = BetterTextArea.buildPlan(dc, label, Graphics.FONT_MEDIUM);
  dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
  BetterTextArea.render(dc, plan);
  if (iconResource != null) {
    var bitmap = WatchUi.loadResource(iconResource);
    dc.drawBitmap(
      (dc.getWidth() - bitmap.getWidth()) / 2,
      dc.getHeight() * 3 / 4 - bitmap.getHeight() / 2,
      bitmap);
  }
}

class SonosGroupView extends WatchUi.View {
  var modeIcon_;

  function initialize() {
      View.initialize();
      SonosController.SelectedGroup.changedCallback = self.method(:onSelectedGroupChanged);
      modeIcon_ = :none;
  }
  
  function onSelectedGroupChanged() {
  	requestUpdate();
  }

  function onUpdate(dc) {
    View.onUpdate(dc);
    drawCenteredLabelAndIcon(
      dc,
      getGroupNameOrInstruction(),
      getModeIconResource());
  }

  private function getGroupNameOrInstruction() {
    var groupName = SonosController.SelectedGroup.getName();
    if (groupName != null) {
      return groupName;
    }
    return WatchUi.loadResource(Rez.Strings.NoGroupSelected);
  }

  private function getModeIconResource() {
    var resource = null;
    switch (modeIcon_) {
      case :play:
        return Rez.Drawables.PlayIcon;
      case :nextTrack:
        return Rez.Drawables.NextTrackIcon;
      case :previousTrack:
        return Rez.Drawables.PreviousTrackIcon;
      default:
        return null;
    }
  }

  function setModeIcon(modeIcon) {
    modeIcon_ = modeIcon;
    requestUpdate();
  }
}

class ButtonTimer {
  var deadline_;
  var callback_;
  var timer_;
  var active_;

  /**
   * deadline: int - millseconds before invoking callback.
   * callback: function()
   */
  function initialize(deadline, callback) {
    deadline_ = deadline;
    callback_ = callback;
    timer_ = new Timer.Timer();
    active_ = false;
  }

  function start() {
    timer_.start(method(:onTimer), deadline_, false);
    active_ = true;
  }

  function onTimer() {
    callback_.invoke();
    reset();
  }

  function reset() {
    timer_.stop();
    active_ = false;
  }

  function isActive() {
    return active_;
  }
}

class ButtonPressCounter {
  var callback_;
  var buttonTimer_;
  var numPresses_;
  var buttonReleased_;
  var timerTriggered_;

  /**
   * deadline: int - millseconds before invoking callback with #presses.
   * callback: function(finalCount: int)
   */
  function initialize(deadline, callback) {
    callback_ = callback;
    buttonTimer_ = new ButtonTimer(deadline, method(:onTimer));
    reset();
  }

  function addButtonPress() {
    numPresses_++;
    buttonReleased_ = false;
    buttonTimer_.start();
    return numPresses_;
  }

  function setButtonReleased() {
    buttonReleased_ = true;
    maybeInvoke();
  }

  function onTimer() {
    timerTriggered_ = true;
    maybeInvoke();
  }

  function reset() {
    buttonTimer_.reset();
    numPresses_ = 0;
    buttonReleased_ = false;
    timerTriggered_ = false;
  }

  function getNumPresses() {
    return numPresses_;
  }

  private function maybeInvoke() {
    if (timerTriggered_ && buttonReleased_) {
      callback_.invoke(numPresses_);
      reset();
    }
  }
}


const MENU_ITEM_UNAUTHORIZE = "unauthorize";
const BUTTON_PRESS_TIMEOUT_MS = 750;
const BUTTON_HOLD_TIMEOUT_MS = 1500;

class SonosGroupViewDelegate extends WatchUi.BehaviorDelegate {
  var view_;
  var selectPressCounter_;
  var playbackStatus_;
  var requestInFlight_;
  var errorView_;
  var extrasButtonTimer_;
  var enterKeyDown_;

  function initialize(view) {
    BehaviorDelegate.initialize();
    view_ = view;
    selectPressCounter_ = new ButtonPressCounter(
      BUTTON_PRESS_TIMEOUT_MS,
      method(:onSelectFinalized));
    extrasButtonTimer_ = new ButtonTimer(
      BUTTON_HOLD_TIMEOUT_MS,
      method(:onExtrasButtonTimer));
    resetState();
  }

  function onHold(clickEvent) {
    showVolumeView();
    return true;
  }

  function onExtrasButtonTimer() {
    showVolumeView();
  }

  private function showVolumeView() {
    resetState();
    var groupId = SonosController.SelectedGroup.getId();
    if (groupId == null) {
      return;
    }
    var progressBar = new WatchUi.ProgressBar(
      WatchUi.loadResource(Rez.Strings.Querying), null);
    var delegate = new SonosGroupVolumeQueryDelegate();
    WatchUi.pushView(
      progressBar,
      delegate,
      WatchUi.SLIDE_IMMEDIATE
    );
    delegate.startQuery();
  }

  function onTap(clickEvent) {
    onEnterOrTap();
    selectPressCounter_.setButtonReleased();
    return true;
  }

  function onKeyPressed(keyEvent) {
    if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
      enterKeyDown_ = true;
      extrasButtonTimer_.start();
      onEnterOrTap();
    }
    return true;
  }

  private function onEnterOrTap() {
    if (requestInFlight_) {
      return;
    }
    var groupId = SonosController.SelectedGroup.getId();
    if (groupId != null) {
      var numPresses = selectPressCounter_.addButtonPress();
      updateModeIcon(numPresses);
    }
  }

  function onKeyReleased(keyEvent) {
    if (keyEvent.getKey() != WatchUi.KEY_ENTER) {
      return false;
    }
    enterKeyDown_ = false;
    selectPressCounter_.setButtonReleased();
    extrasButtonTimer_.reset();
    return true;
  }

  private function resetState() {
    view_.setModeIcon(:none);
    selectPressCounter_.reset();
    extrasButtonTimer_.reset();
    enterKeyDown_ = false;
    requestInFlight_ = false;
    errorView_ = null;
  }

  private function updateModeIcon(pressCount) {
    var modeIcon = :none;
    switch (pressCount) {
      case 1:
        modeIcon = :play;
        break;
      case 2:
        modeIcon = :nextTrack;
        break;
      case 3:
        modeIcon = :previousTrack;
        break;
    }
    view_.setModeIcon(modeIcon);
  }

  function onSelectFinalized(pressCount) {
    switch (pressCount) {
      case 1:
      requestInFlight_ = true;
      SonosController.togglePlayPause(
        SonosController.SelectedGroup.getId(),
        method(:onRequestComplete));
      break;

      case 2:
      requestInFlight_ = true;
      SonosController.skipToNextTrack(
        SonosController.SelectedGroup.getId(),
        method(:onRequestComplete));
      break;

      case 3:
      requestInFlight_ = true;
      SonosController.skipToPreviousTrack(
        SonosController.SelectedGroup.getId(),
        method(:onRequestComplete));
      break;
    }
  }

  function onRequestComplete(error) {
    resetState();
    if (error != null) {
      notifyError(error);
    }
  }

  private function notifyError(error) {
    if (errorView_ != null) {
      // Debounce.
      return;
    }
    errorView_ = new SonosMessageView(error[:message]);
    WatchUi.pushView(
      errorView_,
      null,
      WatchUi.SLIDE_LEFT);
  }

  function onMenu() {
    var progressBar = new WatchUi.ProgressBar(
      WatchUi.loadResource(Rez.Strings.Querying), null);
    var delegate = new SonosGroupSelectMenuBuilderDelegate();
    WatchUi.pushView(
      progressBar,
      delegate,
      WatchUi.SLIDE_IMMEDIATE
    );
    delegate.startDiscovery();
    return true;
  }
}
