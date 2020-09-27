using Toybox.WatchUi;

class SonosMessageView extends WatchUi.View {

  private var message_;

  function initialize(message) {
      View.initialize();
      message_ = message;
  }

  function onUpdate(dc) {
    View.onUpdate(dc);
    var plan = BetterTextArea.buildPlan(
      dc,
      message_,
      Graphics.FONT_MEDIUM);
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    BetterTextArea.render(dc, plan);
  }
}
