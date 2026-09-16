#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
IP="$($DIR/yamaha-ip.sh)" || exit 1
curl -fsS "http://${IP}/YamahaExtendedControl/v1/main/setPower?power=on"
