# unifi

Small helpers for inspecting a UniFi Network Application via the official
integration API (read-only).

## Usage

```sh
export UNIFI_API_KEY=...
export UNIFI_CONSOLE_ID=...
python3 dump.py
```

- `UNIFI_API_KEY`: generate one in UniFi Network -> Settings -> Integrations
  -> API Keys. Keep it secret; rotate if leaked.
- `UNIFI_CONSOLE_ID`: the host ID of your console. Easiest way to find it is
  to list your consoles via the Site Manager API:

  ```sh
  curl -L "https://api.ui.com/v1/hosts" \
    -H "Accept: application/json" -H "X-API-Key: $UNIFI_API_KEY" | jq
  ```

  The `id` field of a host entry is the console ID used by `dump.py`.

## Endpoints used

- `/info`           - application version
- `/sites`          - list of sites
- `/sites/{id}/networks`  - VLANs / networks
- `/sites/{id}/devices`   - UniFi hardware (gateways, switches, APs)
- `/sites/{id}/clients`   - currently connected clients

## API docs

- https://developer.ui.com/network/v10.3.58/gettingstarted
