# Connect IQ: Sonos watch widget

A Garmin Connect IQ watch widget that controls Sonos speaker groups.

* https://apps.garmin.com/
* https://www.sonos.com/

## Contributing

Contributions are welcome. Please first consult the
[contributing](docs/contributing.md) and
[code of conduct](docs/code-of-conduct.md) guides.
Also, please first reach out prior to authoring non-trivial pull requests.

## Getting Started

1. Get the SDK and configure your IDE: https://developer.garmin.com/connect-iq/
1. Establish a Sonos Integration at https://integration.sonos.com/integrations:
    * Redirect URIs: `https://localhost`
    * Event Callback URL: (blank)
1. Paste the key and secret into the appropriate slots in
   [resources/strings/keys.xml](resources/strings/keys.xml)