using Toybox.WatchUi;

class SonosCommunicationErrorView extends WatchUi.View {

  function initialize() {
      View.initialize();
  }

  function onLayout(dc) {
    setLayout(Rez.Layouts.CommunicationError(dc));
  }
}
