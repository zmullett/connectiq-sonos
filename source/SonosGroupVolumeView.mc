using Toybox.WatchUi;

class SonosGroupVolumeQueryDelegate
    extends WatchUi.BehaviorDelegate {

  function initialize() {
    BehaviorDelegate.initialize();
  }

  function startQuery() {
    SonosController.getVolume(
      SonosController.SelectedGroup.getId(),
      method(:onGetVolumeResponse));
  }

  private function notifyError(error) {
    WatchUi.switchToView(
      new SonosMessageView(error[:message]),
      null,
      WatchUi.SLIDE_IMMEDIATE);
  }

  function onGetVolumeResponse(error, volume) {
    if (error != null) {
      notifyError(error);
      return;
    }
    var view = new SonosGroupVolumeView();
    WatchUi.switchToView(
      view,
      new SonosGroupVolumeBehaviorDelegate(view, volume),
      WatchUi.SLIDE_IMMEDIATE);
  }
}

class SonosGroupVolumeView extends WatchUi.View {
  var volume_;

  function initialize() {
      View.initialize();
      volume_ = null;
  }

  function setVolume(volume) {
    volume_ = volume;
    requestUpdate();
  }

  function onUpdate(dc) {
    View.onUpdate(dc);
    if (volume_ != null) {
      dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_DK_GRAY);
      var y = dc.getHeight() * (1 - (volume_) / 100.0);
       dc.fillRectangle(0, y, dc.getWidth(), dc.getHeight());
    }
    drawCenteredLabelAndIcon(
      dc,
      SonosController.SelectedGroup.getName(),
      Rez.Drawables.VolumeIcon);
  }
}

class SonosGroupVolumeBehaviorDelegate extends WatchUi.BehaviorDelegate {
  var view_;
  var localVolume_;
  var remoteVolume_;
  var requestInFlight_;

  function initialize(view, volume) {
    BehaviorDelegate.initialize();
    view_ = view;
    localVolume_ = volume;
    remoteVolume_ = volume;
    requestInFlight_ = false;
    view_.setVolume(localVolume_);
  }

  function onSwipe(swipeEvent) {
    switch (swipeEvent.getDirection()) {
      case WatchUi.SWIPE_DOWN:
        updateVolume(-1);
        return true;
      case WatchUi.SWIPE_UP:
        updateVolume(1);
        return true;
      default:
        return false;
    }
  }

  function onKeyPressed(keyEvent) {
    switch (keyEvent.getKey()) {
      case WatchUi.KEY_DOWN:
        updateVolume(-1);
        return true;
      case WatchUi.KEY_UP:
        updateVolume(1);
        return true;
      default:
        return false;
    }
  }

  private function updateVolume(delta) {
    localVolume_ += delta;
    if (localVolume_ < 0) {
      localVolume_ = 0;
    }
    if (localVolume_ > 100) {
      localVolume_ = 100;
    }
    view_.setVolume(localVolume_);
    maybeSetRelativeVolume();
  }

  private function maybeSetRelativeVolume() {
    if (requestInFlight_) {
      return;
    }
    if (localVolume_ == remoteVolume_) {
      return;
    }
    requestInFlight_ = true;
    SonosController.setRelativeVolume(
      SonosController.SelectedGroup.getId(),
      localVolume_ - remoteVolume_,
      method(:onSetRelativeVolumeResponse));
    remoteVolume_ = localVolume_;
  }

  function onSetRelativeVolumeResponse(error) {
    requestInFlight_ = false;
    if (error != null) {
      notifyError(error);
      return;
    }
    maybeSetRelativeVolume();
  }

  private function notifyError(error) {
    WatchUi.pushView(
      new SonosMessageView(error[:message]),
      null,
      WatchUi.SLIDE_IMMEDIATE);
  }

  function onNextPage() {
    return true;
  }

  function onPreviousPage() {
    return true;
  }

  function onBack() {
    WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    return true;
  }
}
