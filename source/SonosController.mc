using Toybox.Application;
using Toybox.Application.Storage;
using Toybox.Lang;

const SELECTED_GROUP_STORAGE_KEY = "group";
const SELECTED_GROUP_STORAGE_FIELD_ID = "id";
const SELECTED_GROUP_STORAGE_FIELD_NAME = "name";

module SonosController {

module SelectedGroup {
  var changedCallback;
  var group;

  function initialize() {
    group = Storage.getValue(SELECTED_GROUP_STORAGE_KEY);
  }

  function getId() {
    if (group == null) {
      return null;
    }
    return group[SELECTED_GROUP_STORAGE_FIELD_ID];
  }

  function getName() {
    if (group == null) {
      return null;
    }
    return group[SELECTED_GROUP_STORAGE_FIELD_NAME];
  }

  function set(groupId, groupName) {
    group = {
      SELECTED_GROUP_STORAGE_FIELD_ID=>groupId,
      SELECTED_GROUP_STORAGE_FIELD_NAME=>groupName
    };
    Storage.setValue(SELECTED_GROUP_STORAGE_KEY, group);
    changedCallback.invoke();
  }

  function clear() {
    group = null;
    Storage.deleteValue(SELECTED_GROUP_STORAGE_KEY);
    changedCallback.invoke();
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
 * callback: function(error: {}|null)|null
 */
function togglePlayPause(groupId, callback) {
  new Internal.SimplePlaybackHandler(
    groupId, "/togglePlayPause", callback).makeRequest();
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

function getVolume(groupId, callback) {
  new Internal.GetVolumeHandler(groupId, callback).makeRequest();
}

/**
 * volumeDelta: [-100, 100]
 * callback: function(error: {}|null)|null
 */
function setRelativeVolume(groupId, volumeDelta, callback) {
  new Internal.SetRelativeVolumeHandler(
    groupId, volumeDelta, callback).makeRequest();
}

module Internal {

const CONTROL_URL = "https://api.ws.sonos.com/control/api/v1";

function isError(responseCode) {
  return responseCode <= 0 || responseCode >= 400;
}

function getErrorForGeneralMethod(responseCode, data) {
  if (isError(responseCode)) {
    return {
      :message=>Lang.format(
        Application.loadResource(Rez.Strings.CommunicationError),
        [responseCode])
    };
  }
  return null;
}

function getErrorForPlaybackMethod(responseCode, data) {
  if (responseCode >= 400 && data.hasKey("errorCode")) {
    // https://developer.sonos.com/reference/control-api/playback/playback-error/
    switch (data["errorCode"]) {
      case "ERROR_PLAYBACK_NO_CONTENT":
        return {
          :message=>Application.loadResource(Rez.Strings.NoContentError)
        };
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

class GetVolumeHandler {
  var groupId_;
  var callback_;

  function initialize(groupId, callback) {
    groupId_ = groupId;
    callback_ = callback;
  }

  function makeRequest() {
    SonosInterface.makeGetRequest(
      CONTROL_URL + "/groups/" + groupId_ + "/groupVolume",
      method(:onResponse));
  }

  function onResponse(responseCode, data) {
    var volume = null;
    if (data.hasKey("volume")) {
      volume = data["volume"];
    }
    callback_.invoke(
      getErrorForGeneralMethod(responseCode, data),
      volume);
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

class SetRelativeVolumeHandler {
  var groupId_;
  var volumeDelta_;
  var callback_;

  function initialize(groupId, volumeDelta, callback) {
    groupId_ = groupId;
    volumeDelta_ = volumeDelta;
    callback_ = callback;
  }

  function makeRequest() {
    SonosInterface.makePostRequest(
      CONTROL_URL + "/groups/" + groupId_ + "/groupVolume/relative",
      {"volumeDelta" => volumeDelta_},
      method(:onResponse));
  }

  function onResponse(responseCode, data) {
    callback_.invoke(
      getErrorForGeneralMethod(responseCode, data));
  }
}

}  // module Internal
}  // module SonosController