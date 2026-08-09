#!/usr/bin/env python3
"""Dump a summary of a UniFi Network Application via the official integration API.

Auth: API key generated in UniFi Network -> Settings -> Integrations -> API Keys.
The key is read-only and tied to your UI account.
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request

API_BASE = (
    "https://api.ui.com/v1/connector/consoles/{console_id}"
    "/proxy/network/integration/v1"
)


def get(url, api_key):
    req = urllib.request.Request(
        url,
        headers={"Accept": "application/json", "X-API-Key": api_key},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code} {url}\n{e.read().decode()}")
    except urllib.error.URLError as e:
        sys.exit(f"network error: {e}")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--api-key", default=os.environ.get("UNIFI_API_KEY"))
    p.add_argument("--console-id", default=os.environ.get("UNIFI_CONSOLE_ID"))
    args = p.parse_args()
    if not args.api_key or not args.console_id:
        sys.exit(
            "need --api-key and --console-id "
            "(or UNIFI_API_KEY / UNIFI_CONSOLE_ID env vars)"
        )

    base = API_BASE.format(console_id=args.console_id)

    info = get(f"{base}/info", args.api_key)
    version = info.get("applicationVersion", "?")
    print(f"== UniFi Network Application v{version} ==\n")

    sites = get(f"{base}/sites", args.api_key).get("data", [])
    for s in sites:
        print(f"Site: {s['name']}  (id={s['id']}, ref={s.get('internalReference')})")

    for s in sites:
        sid = s["id"]
        print(f"\n--- {s['name']} ---")

        nets = get(f"{base}/sites/{sid}/networks", args.api_key).get("data", [])
        print(f"\nNetworks ({len(nets)}):")
        for n in sorted(nets, key=lambda x: x.get("vlanId", 0)):
            tag = "default" if n.get("default") else n.get("metadata", {}).get("origin", "")
            print(
                f"  {n['name']:<12} VLAN {str(n.get('vlanId', '?')):<4} "
                f"{n.get('management', ''):<10} {tag}"
            )

        devs = get(f"{base}/sites/{sid}/devices", args.api_key).get("data", [])
        dev_map = {d["id"]: d["name"] for d in devs}
        print(f"\nDevices ({len(devs)}):")
        for d in devs:
            print(
                f"  {d['name']:<20} {d.get('model','?'):<18} "
                f"{d.get('state','?'):<8} fw={d.get('firmwareVersion','?')} "
                f"ip={d.get('ipAddress','?')}"
            )

        try:
            clients = get(f"{base}/sites/{sid}/clients", args.api_key).get("data", [])
        except SystemExit:
            clients = []
        print(f"\nClients ({len(clients)}):")
        for c in clients:
            uplink = dev_map.get(c.get("uplinkDeviceId"), "?")
            print(
                f"  {c['name'][:28]:<28} {c.get('type','?'):<9} "
                f"{c.get('ipAddress','?'):<16} uplink={uplink}"
            )


if __name__ == "__main__":
    main()
