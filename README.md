# Alexa Yamaha Bridge

Restore Amazon Alexa power control for Yamaha MusicCast receivers using a Raspberry Pi and Fauxmo with Yamaha's local Extended Control API.

This project was built and tested on a **Raspberry Pi 1** with a **Yamaha R-N803D**. It restores useful Alexa power control after the original Yamaha/MusicCast Alexa integration was discontinued.

## What it does

Alexa sees the Yamaha receiver as a local WeMo-compatible device exposed by Fauxmo. Fauxmo runs local shell commands on the Raspberry Pi. The scripts locate the receiver by its **MAC address**, verify it using Yamaha's `device_id`, and then send the ON/OFF command through the Yamaha Extended Control API.

```text
Alexa
  |
  v
Fauxmo on Raspberry Pi 1
  |
  v
yamaha-on.sh / yamaha-off.sh
  |
  v
yamaha-ip.sh -> MAC address -> current DHCP IP
  |
  v
Yamaha Extended Control API (LAN)
  |
  v
Yamaha R-N803D
```

Working voice commands:

```text
Alexa, turn on Yamaha
Alexa, turn off Yamaha
```

**No static IP address or DHCP reservation is required for the Yamaha receiver.** It can receive a different address from DHCP and the bridge will locate it again.

No Yamaha cloud service, Home Assistant, Node-RED, or additional smart-home hardware is required.

## Requirements

- Raspberry Pi (tested on Raspberry Pi 1)
- Python 3 and a Python virtual environment
- `fauxmo` 0.8.0
- Amazon Alexa / Echo on the same LAN
- Yamaha receiver supporting Yamaha Extended Control API
- Receiver configured for network standby if required by the model
- Receiver MAC address
- Yamaha `device_id`

## 1. Test the Yamaha API

For the initial test, find the receiver's current LAN IP and try:

```bash
curl "http://YAMAHA_IP/YamahaExtendedControl/v1/main/setPower?power=on"
curl "http://YAMAHA_IP/YamahaExtendedControl/v1/main/setPower?power=standby"
```

A successful request returns:

```json
{"response_code":0}
```

Get device information with:

```bash
curl "http://YAMAHA_IP/YamahaExtendedControl/v1/system/getDeviceInfo"
```

Note the receiver's `device_id`. The bridge uses it as an additional check that the IP found from the MAC address really belongs to the expected Yamaha receiver.

## 2. Install Fauxmo

```bash
mkdir -p ~/fauxmo-yamaha
cd ~/fauxmo-yamaha
python3 -m venv .venv
source .venv/bin/activate
pip install fauxmo==0.8.0
```

## 3. Configure dynamic Yamaha discovery

Copy `yamaha-ip.sh`, `yamaha-on.sh` and `yamaha-off.sh` into `~/fauxmo-yamaha/`.

Edit the top of `yamaha-ip.sh` and enter your receiver's values:

```bash
MAC="your:yamaha:mac:address"
DEVICE_ID="YOUR_YAMAHA_DEVICE_ID"
```

The discovery script works in three stages:

1. It first tries the last working address cached in `/tmp/yamaha-ip` and verifies the receiver through `getDeviceInfo`.
2. If necessary, it searches the Raspberry Pi neighbour/ARP table for the configured MAC address.
3. If the MAC is not yet present, it performs a quick local `/24` ping sweep to populate the neighbour table, finds the MAC, and verifies the Yamaha `device_id` before using the address.

The default script scans `192.168.1.1-254`. Change the subnet in `yamaha-ip.sh` if your LAN uses a different range.

Make the scripts executable:

```bash
chmod +x ~/fauxmo-yamaha/yamaha-ip.sh
chmod +x ~/fauxmo-yamaha/yamaha-on.sh
chmod +x ~/fauxmo-yamaha/yamaha-off.sh
```

Test discovery:

```bash
~/fauxmo-yamaha/yamaha-ip.sh
```

It should print the Yamaha's current IP address.

Then test the wrappers:

```bash
~/fauxmo-yamaha/yamaha-on.sh
~/fauxmo-yamaha/yamaha-off.sh
```

## 4. Fauxmo configuration

Copy `config.example.json` to `~/fauxmo-yamaha/config.json` and replace `YOUR_PI_USER` with the Raspberry Pi username.

The important part is that Fauxmo uses `CommandLinePlugin` rather than hard-coded HTTP URLs:

```json
{
  "FAUXMO": {
    "ip_address": "auto"
  },
  "PLUGINS": {
    "CommandLinePlugin": {
      "DEVICES": [
        {
          "name": "Yamaha",
          "port": 12340,
          "on_cmd": "/home/YOUR_PI_USER/fauxmo-yamaha/yamaha-on.sh",
          "off_cmd": "/home/YOUR_PI_USER/fauxmo-yamaha/yamaha-off.sh",
          "use_fake_state": true,
          "initial_state": "off"
        }
      ]
    }
  }
}
```

`use_fake_state` and `initial_state` help Alexa treat the emulated device correctly during discovery.

## 5. Test Fauxmo manually

```bash
cd ~/fauxmo-yamaha
source .venv/bin/activate
fauxmo -c ~/fauxmo-yamaha/config.json
```

Then ask Alexa to discover devices. The new device should appear as **Yamaha**.

Stop the foreground test with `Ctrl+C` before configuring systemd.

## 6. Run Fauxmo automatically with systemd

An example unit is included as `fauxmo-yamaha.service.example`.

Copy it to:

```text
/etc/systemd/system/fauxmo-yamaha.service
```

Replace `YOUR_PI_USER` with your Raspberry Pi username, then run:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now fauxmo-yamaha
```

Check it with:

```bash
systemctl status fauxmo-yamaha --no-pager
sudo ss -lntp | grep 12340
```

## 7. Alexa discovery

In the Alexa app, run device discovery, or say:

```text
Alexa, discover devices
```

If Alexa does not initially discover the Fauxmo device, restart the Echo device and run discovery again. This was required during the original Raspberry Pi 1 setup.

When Alexa asks what is connected to the discovered plug, selecting **Other** is appropriate.

## Tested configuration

The original working setup uses:

- Raspberry Pi 1
- Raspberry Pi OS / Raspbian 13 (Trixie)
- Python 3.13
- Fauxmo 0.8.0
- Yamaha R-N803D
- Dynamic Yamaha IP discovery by MAC address
- Yamaha `device_id` verification
- Fauxmo TCP port 12340
- systemd auto-start

The Raspberry Pi also runs Pi-hole and WireGuard. Fauxmo adds very little CPU or memory load during normal operation.

## Troubleshooting

Check Yamaha discovery:

```bash
~/fauxmo-yamaha/yamaha-ip.sh
```

Remove the cached address and force rediscovery:

```bash
rm -f /tmp/yamaha-ip
~/fauxmo-yamaha/yamaha-ip.sh
```

View Fauxmo logs:

```bash
journalctl -u fauxmo-yamaha -n 100 --no-pager
```

Confirm the service and port:

```bash
systemctl is-active fauxmo-yamaha
sudo ss -lntp | grep 12340
```

## Optional future features

The Yamaha Extended Control API also exposes volume, mute, input selection and other functions. These are intentionally not part of the current stable setup. The goal of this repository is to keep the Raspberry Pi 1 solution simple and reliable.

## Notes

This is an independent community project and is not affiliated with Yamaha, Amazon, or the Fauxmo project.
