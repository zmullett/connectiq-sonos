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
 * callback: function(error: {}|null, householdIds: string[])
 */
function getHouseholds(callback) {
  new Internal.GetHouseholdsHandler(callback).makeRequest();
}

/**
 * callback: function(
 *     error: {}|null,
 *     householdId: string,
 *     Array<{:id=>string, :name=>string}}>
 * )
 */
function getGroups(householdId, callback) {
  new Internal.GetGroupsHandler(householdId, callback).makeRequest();
}

/**
 * callback: function(error: {}|null, playing: boolean)
 */
function getPlaybackStatus(groupId, callback) {
  new Internal.GetPlaybackStatusHandler(groupId, callback).makeRequest();
}

/**
 * callback: function(error: {}|null)|null
 */
function play(groupId, callback) {
  new Internal.SimplePlaybackHandler(
    groupId, "/play", callback).makeRequest();
}

/**
 * callback: function(error: {}|null)|null
 */
function pause(groupId, callback) {
  new Internal.SimplePlaybackHandler(
    groupId, "/pause", callback).makeRequest();
}

/**
 * callback: function(error: {}|null)|null
 */
function skipToNextTrack(groupId, callback) {
  new Internal.SimplePlaybackHandler(
    groupId, "/skipToNextTrack", callback).makeRequest();
}

/**
 * callback: function(error: {}|null)|null
 */
function skipToPreviousTrack(groupId, callback) {
  new Internal.SimplePlaybackHandler(
    groupId, "/skipToPreviousTrack", callback).makeRequest();
}

module Internal {

const CONTROL_URL = "https://api.ws.sonos.com/control/api/v1";

function isError(responseCode) {
  return responseCode <= 0 || responseCode >= 400;
}

function getErrorForGeneralMethod(responseCode, data) {
  if (isError(responseCode)) {
    return {:message=>Rez.Strings.CommunicationError};
  }
  return null;
}

function getErrorForPlaybackMethod(responseCode, data) {
  if (responseCode >= 400 && data.hasKey("errorCode")) {
    // https://developer.sonos.com/reference/control-api/playback/playback-error/
    switch (data["errorCode"]) {
      case "ERROR_PLAYBACK_NO_CONTENT":
        return {:message=>Rez.Strings.NoContentError};
    }
  }
  return getErrorForGeneralMethod(responseCode, data);
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
    if (data.hasKey("households")) {
      var households = data["households"];
      for (var i = 0; i < households.size(); i++) {
        var id = households[i]["id"];
        if (id) {
          result.add(id);
        }
      }
    }
    callback_.invoke(
      getErrorForGeneralMethod(responseCode, data),
      result);
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
    if (data.hasKey("groups")) {
      var groups = data["groups"];
      for (var i = 0; i < groups.size(); i++) {
        var id = groups[i]["id"];
        var name = groups[i]["name"];
        if (id != null && name != null) {
          result.add({:id=>id, :name=>name});
        }
      }
    }
    callback_.invoke(
      getErrorForGeneralMethod(responseCode, data),
      householdId_,
      result);
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
    if (data.hasKey("playbackState")) {
      playing = data["playbackState"].equals("PLAYBACK_STATE_PLAYING");
    }
    callback_.invoke(
      getErrorForGeneralMethod(responseCode, data),
      playing);
  }
}

class SimplePlaybackHandler {
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
      CONTROL_URL + "/groups/" + groupId_ + "/playback" + resource_,
      null,
      method(:onResponse));
  }

  function onResponse(responseCode, data) {
    callback_.invoke(getErrorForPlaybackMethod(responseCode, data));
  }
}

}  // module Internal
}  // module SonosController