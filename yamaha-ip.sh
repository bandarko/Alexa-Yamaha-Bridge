#!/bin/bash
set -u

# REQUIRED: replace with the MAC address of your Yamaha receiver.
YAMAHA_MAC="aa:bb:cc:dd:ee:ff"
CACHE="/tmp/yamaha-ip"

# Automatically determine the IPv4 /24 network used by the default route.
LOCAL_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')
[ -n "${LOCAL_IP:-}" ] || { echo "Could not determine local IPv4 address." >&2; exit 1; }
SUBNET="${LOCAL_IP%.*}"

check_yamaha() {
    local ip="${1:-}"
    [ -n "$ip" ] || return 1
    curl -fsS --connect-timeout 1 --max-time 2 \
        "http://${ip}/YamahaExtendedControl/v1/system/getDeviceInfo" >/dev/null 2>&1
}

find_by_mac() {
    ip neigh 2>/dev/null | awk -v mac="$YAMAHA_MAC" '
        tolower($0) ~ tolower(mac) && $1 ~ /^[0-9]+\./ {print $1; exit}
    '
}

# 1. Fast path: try the last working address.
if [ -f "$CACHE" ]; then
    IP=$(cat "$CACHE")
    if check_yamaha "$IP"; then
        echo "$IP"
        exit 0
    fi
fi

# 2. Check the current neighbour/ARP table for the configured MAC address.
IP=$(find_by_mac)
if [ -n "${IP:-}" ] && check_yamaha "$IP"; then
    echo "$IP" > "$CACHE"
    echo "$IP"
    exit 0
fi

# 3. Populate the neighbour table, then look for the MAC again.
for i in $(seq 1 254); do
    ping -c 1 -W 1 "${SUBNET}.${i}" >/dev/null 2>&1 &
done
wait

IP=$(find_by_mac)
if [ -n "${IP:-}" ] && check_yamaha "$IP"; then
    echo "$IP" > "$CACHE"
    echo "$IP"
    exit 0
fi

echo "Yamaha not found. Check YAMAHA_MAC and make sure the receiver is reachable on the same LAN." >&2
exit 1
