using Toybox.Application.Storage;

const SELECTED_GROUP_STORAGE_KEY = "group";
const SELECTED_GROUP_STORAGE_FIELD_ID = "id";
const SELECTED_GROUP_STORAGE_FIELD_NAME = "name";

module SonosController {

class SelectedGroupListener {
  var selectedGroupChangedCallback_;

  function initialize(selectedGroupChangedCallback) {
    selectedGroupChangedCallback_ = selectedGroupChangedCallback;
  }

  function getGroupId() {
    var group = Storage.getValue(SELECTED_GROUP_STORAGE_KEY);
    if (group == null) {
      return null;
    }
    return group[SELECTED_GROUP_STORAGE_FIELD_ID];
  }

  function getGroupName() {
    var group = Storage.getValue(SELECTED_GROUP_STORAGE_KEY);
    if (group == null) {
      return null;
    }
    return group[SELECTED_GROUP_STORAGE_FIELD_NAME];
  }

  function set(groupId, groupName) {
    Storage.setValue(SELECTED_GROUP_STORAGE_KEY, {
      SELECTED_GROUP_STORAGE_FIELD_ID=>groupId,
      SELECTED_GROUP_STORAGE_FIELD_NAME=>groupName
    });
    selectedGroupChangedCallback_.invoke();
  }

  function clear() {
    Storage.deleteValue(SELECTED_GROUP_STORAGE_KEY);
    selectedGroupChangedCallback_.invoke();
  }
}

/**
 * callback: function(success: boolean, householdIds: string[])
 */
function getHouseholds(callback) {
  new Internal.GetHouseholdsHandler(callback).makeRequest();
}

/**
 * callback: function(
 *     success: boolean,
 *     householdId: string,
 *     Array<{:id=>string, :name=>string}}>
 * )
 */
function getGroups(householdId, callback) {
  new Internal.GetGroupsHandler(householdId, callback).makeRequest();
}

/**
 * callback: function(success: boolean, playing: boolean)
 */
function getPlaybackStatus(groupId, callback) {
  new Internal.GetPlaybackStatusHandler(groupId, callback).makeRequest();
}

/**
 * callback: function(success: boolean)|null
 */
function play(groupId, callback) {
  new Internal.SimpleControlGroupPostHandler(
    groupId, "/playback/play", callback).makeRequest();
}

/**
 * callback: function(success: boolean)|null
 */
function pause(groupId, callback) {
  new Internal.SimpleControlGroupPostHandler(
    groupId, "/playback/pause", callback).makeRequest();
}

/**
 * callback: function(success: boolean)|null
 */
function skipToNextTrack(groupId, callback) {
  new Internal.SimpleControlGroupPostHandler(
    groupId, "/playback/skipToNextTrack", callback).makeRequest();
}

/**
 * callback: function(success: boolean)|null
 */
function skipToPreviousTrack(groupId, callback) {
  new Internal.SimpleControlGroupPostHandler(
    groupId, "/playback/skipToPreviousTrack", callback).makeRequest();
}

module Internal {

const CONTROL_URL = "https://api.ws.sonos.com/control/api/v1";

function isError(responseCode) {
  return responseCode <= 0 || responseCode >= 400;
}

class GetHouseholdsHandler {
  var callback_;

  function initialize(callback) {
    callback_ = callback;
  }

  function makeRequest() {
    SonosInterface.makeGetRequest(
      CONTROL_URL + "/households",
      method(:onResponse));
  }

  function onResponse(responseCode, data) {
    var result = [];
    if (data != null) {
      var households = data["households"];
      for (var i = 0; i < households.size(); i++) {
        result.add(households[i]["id"]);
      }
    }
    callback_.invoke(!isError(responseCode), result);
  }
}

class GetGroupsHandler {
  var householdId_;
  var callback_;

  function initialize(householdId, callback) {
    householdId_ = householdId;
    callback_ = callback;
  }

  function makeRequest() {
    SonosInterface.makeGetRequest(
      CONTROL_URL + "/households/" + householdId_ + "/groups",
      method(:onResponse));
  }

  function onResponse(responseCode, data) {
    var result = [];
    if (data != null) {
      var groups = data["groups"];
      for (var i = 0; i < groups.size(); i++) {
        result.add({
          :id=>groups[i]["id"],
          :name=>groups[i]["name"]
        });
      }
    }
    callback_.invoke(!isError(responseCode), householdId_, result);
  }
}

class GetPlaybackStatusHandler {
  var groupId_;
  var callback_;

  function initialize(groupId, callback) {
    groupId_ = groupId;
    callback_ = callback;
  }

  function makeRequest() {
    SonosInterface.makeGetRequest(
      CONTROL_URL + "/groups/" + groupId_ + "/playback",
      method(:onResponse));
  }

  function onResponse(responseCode, data) {
    var playing = null;
    if (data != null) {
      playing = data["playbackState"].equals("PLAYBACK_STATE_PLAYING");
    }
    callback_.invoke(!isError(responseCode), playing);
  }
}

class SimpleControlGroupPostHandler {
  var groupId_;
  var resource_;
  var callback_;

  function initialize(groupId, resource, callback) {
    groupId_ = groupId;
    resource_ = resource;
    callback_ = callback;
  }

  function makeRequest() {
    SonosInterface.makePostRequest(
      CONTROL_URL + "/groups/" + groupId_ + resource_,
      null,
      method(:onResponse));
  }

  function onResponse(responseCode, data) {
    if (callback_) {
      callback_.invoke(!isError(responseCode));
    }
  }
}

}  // module Internal
}  // module SonosController