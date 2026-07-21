#!/usr/bin/env bash
set -euo pipefail

if ((EUID != 0)); then
  echo "Run this script as root." >&2
  exit 1
fi

hostname=$(hostname --short)
case "$hostname" in
  spark-0[1-4])
    node_id=${hostname#spark-0}
    node_id=$((10#$node_id))
    ;;
  *)
    echo "Unsupported hostname: $hostname" >&2
    exit 1
    ;;
esac

configure_interface() {
  local interface=$1
  local subnet=$2
  local connection

  if [[ ! -e /sys/class/net/$interface ]]; then
    echo "Missing interface: $interface" >&2
    exit 1
  fi

  connection=$(nmcli -g GENERAL.CONNECTION device show "$interface")
  if [[ -z $connection || $connection == "--" ]]; then
    echo "No active NetworkManager connection for $interface" >&2
    exit 1
  fi

  nmcli connection modify "$connection" \
    connection.autoconnect yes \
    connection.interface-name "$interface" \
    802-3-ethernet.mtu 9000 \
    ipv4.method manual \
    ipv4.addresses "10.100.$subnet.$node_id/24" \
    ipv4.gateway "" \
    ipv4.routes "" \
    ipv4.dns "" \
    ipv4.never-default yes \
    ipv4.ignore-auto-dns yes \
    ipv6.method disabled

  nmcli connection down "$connection" || true
  nmcli connection up "$connection" ifname "$interface"
}

configure_interface enp1s0f0np0 0
configure_interface enP2p1s0f0np0 1

ip -br address show enp1s0f0np0
ip -br address show enP2p1s0f0np0
