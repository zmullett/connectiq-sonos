using Toybox.Application;
using Toybox.Application.Storage;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.StringUtil;

module SonosInterface {

const TOKENS_STORAGE_KEY = "tokens";
const TOKENS_STORAGE_FIELD_ACCESS = "access";
const TOKENS_STORAGE_FIELD_REFRESH = "refresh";

function isAuthorizationRequired() {
  return Storage.getValue(TOKENS_STORAGE_KEY) == null;
}

function removeAuthorization() {
  Storage.deleteValue(TOKENS_STORAGE_KEY);
}

/**
 * callback: function(responseCode: int, data: JSON dict)
 */
function makeRequest(method, url, callback) {
  new Internal.RequestHandler(method, url, callback).makeRequest();
}

function makeGetRequest(url, callback) {
  makeRequest(Communications.HTTP_REQUEST_METHOD_GET, url, callback);
}

function makePostRequest(url, payload, callback) {
  makeRequest(Communications.HTTP_REQUEST_METHOD_POST, url, callback);
}

function createOAuthHandler(callback) {
  return new Internal.AuthorizationHandler(callback);
}

module Internal {

const AUTH_URL = "https://api.sonos.com/login/v3/oauth";

function getTokensSafe() {
  var tokens = Storage.getValue(TOKENS_STORAGE_KEY);
  if (tokens == null) {
    return {
      TOKENS_STORAGE_FIELD_ACCESS=>null,
      TOKENS_STORAGE_FIELD_REFRESH=>null
    };
  }
  return tokens;
}

function getBasicAuthorizationHeaderValue() {
  var key = Application.loadResource(Rez.Strings.SonosIntegrationKey);
  var secret = Application.loadResource(Rez.Strings.SonosIntegrationSecret);
  return "Basic " + StringUtil.encodeBase64(key + ":" + secret);
}

function getBearerAuthorizationHeaderValue() {
  return "Bearer " + getTokensSafe()[TOKENS_STORAGE_FIELD_ACCESS];
}

/**
 * Handles authorization to Sonos via OAuth. Use createOAuthHandler() instead
 * of instantiating this directly.
 */
class AuthorizationHandler {
  var callback_;

  function initialize(callback) {
    callback_ = callback;
  }

  function registerForOAuthMessages() {
    Communications.registerForOAuthMessages(method(:onOAuthMessage));
  }

  function makeOAuthRequest() {
    var clientId = Application.loadResource(Rez.Strings.SonosIntegrationKey);
    Communications.makeOAuthRequest(
      AUTH_URL,
      {
        "scope" => "playback-control-all",
        "redirect_uri" => "https://localhost",
        "response_type" => "code",
        "client_id" => clientId,
        "state" => "unused",
      },
      "https://localhost",
      Communications.OAUTH_RESULT_TYPE_URL,
      {"code"=> "code", "error" => "error"}
    );
  }

  function onOAuthMessage(value) {
    if(value.data == null) {
      callback_.invoke(
        /*communicationSuccess=*/false,
        /*authorizationSuccess=*/null);
      return;
    }
    if (value.data["error"]) {
      callback_.invoke(
        /*communicationSuccess=*/true,
        /*authorizationSuccess=*/false);
      return;
    }
    var code = value.data["code"];
    Communications.makeWebRequest(
      AUTH_URL + "/access",
      {
        "grant_type" => "authorization_code",
        "code" => code,
        "redirect_uri" => "https://localhost"
      },
      {
        :method => Communications.HTTP_REQUEST_METHOD_POST,
        :headers => {"Authorization" => getBasicAuthorizationHeaderValue()}
      },
      method(:onAccessResponse)
    );
  }

  function onAccessResponse(responseCode, data) {
    if(responseCode != 200 || data == null) {
      callback_.invoke(
        /*communicationSuccess=*/true,
        /*authorizationSuccess=*/false
      );
      return;
    }
    Storage.setValue(TOKENS_STORAGE_KEY, {
      TOKENS_STORAGE_FIELD_ACCESS=>data["access_token"],
      TOKENS_STORAGE_FIELD_REFRESH=>data["refresh_token"]
    });
    callback_.invoke(
      /*communicationSuccess=*/true,
      /*authorizationSuccess=*/true);
  }
}

/**
 * Handles making of authorized requests to Sonos endpoints, with automatic
 * refreshing of the access token once expired. Use makeRequest() isntead of
 * instantiating this directly.
 */
class RequestHandler {
  var method_;
  var url_;
  var callback_;
  var attemptedTokenRefresh_ = false;

  function initialize(method, url, callback) {
    method_ = method;
    url_ = url;
    callback_ = callback;
  }

  function makeRequest() {
    Communications.makeWebRequest(
      url_, {}, {
        :method => method_,
        :headers => {
          "Authorization" => Internal.getBearerAuthorizationHeaderValue(),
          "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
        },
        :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
      }, method(:onResponse));
  }

  function onResponse(responseCode, data) {
    if (responseCode == 401 && !attemptedTokenRefresh_) {
      attemptedTokenRefresh_ = true;
      makeTokenRefreshRequest();
      return;
    }
    if (data == null) {
      data = {};
    }
    if (callback_ != null) {
      callback_.invoke(responseCode, data);
    }
  }

  private function makeTokenRefreshRequest() {
    Communications.makeWebRequest(
      AUTH_URL + "/access", {
        "refresh_token" => getTokensSafe()[TOKENS_STORAGE_FIELD_REFRESH],
        "grant_type" => "refresh_token",
      }, {
        :method => Communications.HTTP_REQUEST_METHOD_POST,
        :headers => {"Authorization" => getBasicAuthorizationHeaderValue()},
        :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
      }, method(:onTokenRefreshResponse));
  }

  function onTokenRefreshResponse(responseCode, data) {
    Storage.setValue(TOKENS_STORAGE_KEY, {
      TOKENS_STORAGE_FIELD_ACCESS=>data["access_token"],
      TOKENS_STORAGE_FIELD_REFRESH=>data["refresh_token"]
    });
    makeRequest();  // Retry original request.
  }
}

}  // module Internal
}  // module SonosInterface