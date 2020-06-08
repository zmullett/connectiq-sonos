using Toybox.Timer;
using Toybox.WatchUi;

class SonosGroupView extends WatchUi.View {
  var selectedGroupListener_;
  var modeIcon_;

  function initialize() {
      View.initialize();
      selectedGroupListener_ = new SonosController.SelectedGroupListener(
        method(:onSelectedGroupChanged));
      modeIcon_ = :none;
  }

  function onLayout(dc) {
    setLayout(Rez.Layouts.Group(dc));
  }

  function onSelectedGroupChanged() {
    maybeUpdateGroupName();
  }

  function maybeUpdateGroupName() {
    if (selectedGroupListener_ == null) {
      // Called before the view is ready.
      return;
    }
    var groupName = selectedGroupListener_.getGroupName();
    if (groupName == null) {
      groupName = WatchUi.loadResource(Rez.Strings.NoGroupSelected);
    }
    View.findDrawableById("groupName").setText(groupName);
  }

  function onUpdate(dc) {
    View.onUpdate(dc);
    maybeUpdateGroupName();
    maybeDrawModeIcon(dc);
  }

  private function maybeDrawModeIcon(dc) {
    var resource = null;
    switch (modeIcon_) {
      case :play:
        resource = Rez.Drawables.PlayIcon;
        break;
      case :nextTrack:
        resource = Rez.Drawables.NextTrackIcon;
        break;
      case :previousTrack:
        resource = Rez.Drawables.PreviousTrackIcon;
        break;
    }
    if (resource) {
      var bitmap = WatchUi.loadResource(resource);
      dc.drawBitmap(
        (dc.getWidth() - bitmap.getWidth()) / 2,
        dc.getHeight() * 3 / 4 - bitmap.getHeight() / 2,
        bitmap);
    }
  }

  function setModeIcon(modeIcon) {
    modeIcon_ = modeIcon;
    requestUpdate();
  }

  function getSelectedGroupListener() {
    return selectedGroupListener_;
  }
}

class ButtonPressCounter {
  var deadline_;
  var callback_;
  var timer_ = new Timer.Timer();
  var numPresses_ = 0;

  /**
   * deadline: int - millseconds before invoking callback with #presses.
   * callback: function(finalCount: int)
   */
  function initialize(deadline, callback) {
    deadline_ = deadline;
    callback_ = callback;
  }

  function addButtonPress() {
    numPresses_++;
    timer_.start(method(:onTimer), deadline_, false);
    return numPresses_;
  }

  function onTimer() {
    callback_.invoke(numPresses_);
    cancel();
  }

  function cancel() {
    timer_.stop();
    numPresses_ = 0;
  }
}


const MENU_ITEM_UNAUTHORIZE = "unauthorize";
const BUTTON_PRESS_TIMEOUT_MS = 750;

class SonosGroupViewDelegate extends WatchUi.BehaviorDelegate {
  var view_;
  var selectPressCounter_;
  var playbackStatus_;
  var playbackToggleRequested_;
  var requestInFlight_;
  var errorView_;

  function initialize(view) {
    BehaviorDelegate.initialize();
    view_ = view;
    selectPressCounter_ = new ButtonPressCounter(
      BUTTON_PRESS_TIMEOUT_MS, method(:onSelectFinalized));
    resetState();
  }

  function getSelectedGroupId() {
    return view_.getSelectedGroupListener().getGroupId();
  }

  function onSelect() {
    if (!requestInFlight_) {
      var groupId = getSelectedGroupId();
      if (groupId != null) {
        var numPresses = selectPressCounter_.addButtonPress();
        updateModeIcon(numPresses);
        if (numPresses == 1) {
          resetState();
          SonosController.getPlaybackStatus(
            groupId, method(:onPlaybackStatus));
        }
      }
    }
    return true;
  }

  private function resetState() {
    requestInFlight_ = false;
    playbackStatus_ = null;
    playbackToggleRequested_ = false;
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
      // Toggle playback once playback state has been ascertained.
      playbackToggleRequested_ = true;
      maybeTogglePlayback();
      break;

      case 2:
      requestInFlight_ = true;
      SonosController.skipToNextTrack(
        getSelectedGroupId(),
        method(:onRequestComplete));
      break;

      case 3:
      requestInFlight_ = true;
      SonosController.skipToPreviousTrack(
        getSelectedGroupId(),
        method(:onRequestComplete));
      break;
    }
  }

  function onPlaybackStatus(success, playing) {
    if (!success) {
      view_.setModeIcon(:none);
      selectPressCounter_.cancel();
      notifyCommunicationError();
      return;
    }
    playbackStatus_ = playing;
    maybeTogglePlayback();
  }

  private function maybeTogglePlayback() {
    if (playbackStatus_ == null || !playbackToggleRequested_) {
      return;  // Not ready or not required.
    }
    var groupId = getSelectedGroupId();
    requestInFlight_ = true;
    if (playbackStatus_) {
      SonosController.pause(groupId, method(:onRequestComplete));
    } else {
      SonosController.play(groupId, method(:onRequestComplete));
    }
  }

  function onRequestComplete(success) {
    requestInFlight_ = false;
    view_.setModeIcon(:none);
    if (!success) {
      notifyCommunicationError();
    }
  }

  private function notifyCommunicationError() {
    if (errorView_ != null) {
      // Debounce.
      return;
    }
    errorView_ = new SonosMessageView(Rez.Strings.CommunicationError);
    WatchUi.pushView(
      errorView_,
      null,
      WatchUi.SLIDE_RIGHT);
  }

  function onMenu() {
    var progressBar = new WatchUi.ProgressBar(
      WatchUi.loadResource(Rez.Strings.Querying), null);
    var delegate = new SonosGroupMenuBuilderDelegate(
        view_.getSelectedGroupListener());
    WatchUi.pushView(
      progressBar,
      delegate,
      WatchUi.SLIDE_IMMEDIATE
    );
    delegate.startDiscovery();
    return true;
  }
}
