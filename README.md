# Alexa Yamaha Bridge

Restore Amazon Alexa power control for Yamaha MusicCast receivers using a Raspberry Pi and Fauxmo with Yamaha's local Extended Control API.

This project was built and tested on a **Raspberry Pi 1** with a **Yamaha R-N803D**. It restores the useful voice commands after the original Yamaha/MusicCast Alexa integration was discontinued.

## What it does

Alexa sees the Yamaha receiver as a local WeMo-compatible smart device exposed by Fauxmo. Fauxmo translates Alexa ON/OFF requests into Yamaha Extended Control API calls over the local network.

```text
Alexa
  |
  v
Fauxmo on Raspberry Pi 1
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

No Yamaha cloud service, Home Assistant, Node-RED, or additional smart-home hardware is required.

## Requirements

- Raspberry Pi (tested on Raspberry Pi 1)
- Python 3 and a Python virtual environment
- `fauxmo` 0.8.0
- Amazon Alexa / Echo on the same LAN
- Yamaha receiver supporting Yamaha Extended Control API
- Receiver configured for network standby if required by the model
- Static/reserved IP addresses are recommended

## 1. Test the Yamaha API

Replace `YAMAHA_IP` with your receiver's LAN address.

Power on:

```bash
curl "http://YAMAHA_IP/YamahaExtendedControl/v1/main/setPower?power=on"
```

Standby:

```bash
curl "http://YAMAHA_IP/YamahaExtendedControl/v1/main/setPower?power=standby"
```

A successful request returns:

```json
{"response_code":0}
```

You can also check the receiver status:

```bash
curl "http://YAMAHA_IP/YamahaExtendedControl/v1/main/getStatus"
```

Do not continue until direct API power control works.

## 2. Install Fauxmo

Example installation under the current user's home directory:

```bash
mkdir -p ~/fauxmo-yamaha
cd ~/fauxmo-yamaha
python3 -m venv .venv
source .venv/bin/activate
pip install fauxmo==0.8.0
```

## 3. Fauxmo configuration

Create `~/fauxmo-yamaha/config.json`:

```json
{
  "FAUXMO": {
    "ip_address": "auto"
  },
  "PLUGINS": {
    "SimpleHTTPPlugin": {
      "DEVICES": [
        {
          "name": "Yamaha",
          "port": 12340,
          "on_cmd": "http://YAMAHA_IP/YamahaExtendedControl/v1/main/setPower?power=on",
          "off_cmd": "http://YAMAHA_IP/YamahaExtendedControl/v1/main/setPower?power=standby",
          "use_fake_state": true,
          "initial_state": "off"
        }
      ]
    }
  }
}
```

Replace both occurrences of `YAMAHA_IP` with the receiver's actual LAN IP address.

`use_fake_state` and `initial_state` are important for Alexa discovery because Alexa may query the device state while adding the emulated device.

## 4. Test Fauxmo manually

```bash
cd ~/fauxmo-yamaha
source .venv/bin/activate
fauxmo -c ~/fauxmo-yamaha/config.json
```

Then ask Alexa to discover devices. The new device should appear as **Yamaha**.

Stop the foreground test with `Ctrl+C` before configuring systemd.

## 5. Run Fauxmo automatically with systemd

Create:

```text
/etc/systemd/system/fauxmo-yamaha.service
```

Example service:

```ini
[Unit]
Description=Fauxmo Yamaha Alexa Bridge
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=YOUR_PI_USER
WorkingDirectory=/home/YOUR_PI_USER/fauxmo-yamaha
ExecStart=/home/YOUR_PI_USER/fauxmo-yamaha/.venv/bin/fauxmo -c /home/YOUR_PI_USER/fauxmo-yamaha/config.json
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Replace `YOUR_PI_USER` with your Raspberry Pi username.

Enable it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now fauxmo-yamaha
```

Check status:

```bash
systemctl status fauxmo-yamaha --no-pager
```

Check that Fauxmo is listening:

```bash
sudo ss -lntp | grep 12340
```

## 6. Alexa discovery

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
- Fauxmo TCP port 12340
- systemd auto-start

The Raspberry Pi also runs Pi-hole and WireGuard. Fauxmo adds very little CPU or memory load during normal operation.

## Troubleshooting

View service logs:

```bash
journalctl -u fauxmo-yamaha -n 100 --no-pager
```

Confirm the service is running:

```bash
systemctl is-active fauxmo-yamaha
```

Confirm the port is listening:

```bash
sudo ss -lntp | grep 12340
```

If the Yamaha API commands work with `curl` but Alexa does not discover the device, the problem is on the Fauxmo/Alexa discovery side rather than the Yamaha API side.

## Optional future features

The Yamaha Extended Control API also exposes volume, mute, input selection and other functions. These are intentionally not part of the current stable setup. The goal of this repository is to keep the Raspberry Pi 1 solution simple and reliable.

## Notes

This is an independent community project and is not affiliated with Yamaha, Amazon, or the Fauxmo project.
