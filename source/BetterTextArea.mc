using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;

/**
 * Formats text in the center of the screen, respecting screen geometry.
 */
module BetterTextArea {

/**
 * Builds a rendering plan usable by render().
 */
function buildPlan(dc, text, font) {
  Internal.prepareOnce();
  var fontDimensions = Internal.getFontDimensions(dc, font);
  var words = Internal.splitAndMeasure(text, dc, font);
  var y = Internal.SCREEN_HEIGHT / 2;
  var maxLines = 0;  // Increase as the algorithm retries to fit the text.
  var lines;
  var remainingWordIndices;
  // This iteration will repeat, increasing the number of lines each time,
  // until all text fits or a boundary is exceeded.
  do {
    // Initially this subtraction places the starting line ready to render a
    // single line of vertically-centered text. For every iteration, this
    // starting vertical position is raised such that the lines of text remain
    // centered on the screen.
    y -= fontDimensions[:lineHeight] / 2;
    maxLines++;
    lines = [];
    remainingWordIndices = Internal.range(words);
    var yLine = y;
    var iLine = 0;
    // This iteration continues to build lines until the target number of lines
    // is exceeded. The available width on rounded screen geometries is
    // dependent on the vertical screen position, so when maxLines is
    // incremented then all word positions need recalculating.
    while (iLine < maxLines && remainingWordIndices.size() > 0) {
      var lineContent = [];
      var availableWidth = Internal.getMinimumAvailableWidthForFont(
        fontDimensions[:lineHeight],
        yLine);
      var remainingWidth = availableWidth;
      // This iteration fits words onto a line. The pixel width of words is
      // known, as well as the available width at this particular height on
      // the screen.
      while (remainingWordIndices.size() > 0) {
        var wordIndex = remainingWordIndices[0];
        var wordWidth = words[wordIndex][:width];
        if (lineContent.size() > 0) {
          wordWidth += fontDimensions[:spaceWidth];
        }
        var atLeastOneWord = lineContent.size() > 0;
        if (wordWidth > remainingWidth && atLeastOneWord) {
          // Insufficient space for another word. Do not break early if the
          // line is empty; this implies the current word is wider than the
          // available width; choose to render it clipped.
          break;
        }
        lineContent.add(wordIndex);
        remainingWordIndices = remainingWordIndices.slice(1, null);
        remainingWidth -= wordWidth;
      }
      lines.add({
        :indices => lineContent,
        :y => yLine,
        :availableWidth => availableWidth,
      });
      iLine++;
      yLine += fontDimensions[:lineHeight];
    }
  } while (remainingWordIndices.size() > 0 && y >= 0);

  var result = [];
  for (var iLine = 0; iLine < lines.size(); iLine++) {
    var indices = lines[iLine][:indices];
    var text = "";
    var width = 0;
    for (var iWord = 0; iWord < indices.size(); iWord++) {
      if (iWord > 0) {
        text += " ";
        width += fontDimensions[:spaceWidth];
      }
      var word = words[indices[iWord]];
      text += word[:text];
      width += word[:width];
    }
    result.add({
      :text => text,
      :x => (Internal.SCREEN_WIDTH - width) / 2,
      :y => lines[iLine][:y],
    });
  }
  return {
    :lines => result,
    :font => font,
  };
}

function render(dc, plan) {
  var font = plan[:font];
  var lines = plan[:lines];
  for (var i = 0; i < lines.size(); i++) {
    dc.drawText(
      lines[i][:x],
      lines[i][:y],
      font,
      lines[i][:text],
      Graphics.TEXT_JUSTIFY_LEFT);
  }
}

module Internal {

const SPACE = " ";
var WIDTH_CACHE = null;
var SCREEN_WIDTH = null;
var SCREEN_HEIGHT = null;

function getFontDimensions(dc, font) {
  var spaceDimensions = dc.getTextDimensions(SPACE, font);
  return {
    :spaceWidth=>spaceDimensions[0],
    :lineHeight=>spaceDimensions[1],
  };
}

function splitAndMeasure(text, dc, font) {
  var charArray = text.toCharArray();
  var words = [""];
  for (var i=0; i < charArray.size(); i++) {
    if (charArray[i] == ' ') {
      words.add("");
    } else {
      words[words.size()-1] += charArray[i];
    }
  }
  var result = [];
  for (var i = 0; i < words.size(); i++) {
    result.add({
      :text => words[i],
      :width => dc.getTextWidthInPixels(words[i], font),
    });
  }
  return result;
}

function range(array) {
  var indices = [];
  for (var i = 0; i < array.size(); i++) {
    indices.add(i);
  }
  return indices;
}

function getAvailableWidth(y) {
  var i = ((y + 0.5 - SCREEN_HEIGHT / 2).abs() - 0.5).toNumber()
    % WIDTH_CACHE.size();
  return WIDTH_CACHE[i];
}

function min(a, b) {
  if (a <= b) {
    return a;
  }
  return b;
}

function getMinimumAvailableWidthForFont(lineHeight, y) {
  return min(getAvailableWidth(y), getAvailableWidth(y + lineHeight));
}

function prepareOnce() {
  if (WIDTH_CACHE != null) {
    return;
  }
  var deviceSettings = System.getDeviceSettings();
  SCREEN_WIDTH = deviceSettings.screenWidth;
  SCREEN_HEIGHT = deviceSettings.screenHeight;
  WIDTH_CACHE = [];
  if (deviceSettings.screenShape == System.SCREEN_SHAPE_RECTANGLE) {
    WIDTH_CACHE.add(SCREEN_WIDTH);
    return;
  }
  var w_screen_squared = SCREEN_WIDTH * SCREEN_WIDTH;
  var h_screen_half = SCREEN_HEIGHT / 2;
  for (var y = h_screen_half; y < SCREEN_HEIGHT; y++) {
    var h = 2 * y - SCREEN_HEIGHT;
    var w_line = Math.sqrt(w_screen_squared - h * h);
    WIDTH_CACHE.add(w_line);
  }
}

}  // module Internal

}  // module BetterTextArea