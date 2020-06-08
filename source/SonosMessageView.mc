using Toybox.WatchUi;

class SonosMessageView extends WatchUi.View {

  private var message_;

  function initialize(message) {
      View.initialize();
      message_ = message;
  }

  function onLayout(dc) {
    setLayout(Rez.Layouts.Message(dc));
    findDrawableById("message").setText(message_);
  }
}
