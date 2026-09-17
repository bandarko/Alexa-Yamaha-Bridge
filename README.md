# Alexa Yamaha Bridge

Restore Amazon Alexa ON/OFF control for a Yamaha MusicCast receiver using a Raspberry Pi, Fauxmo and Yamaha's local Extended Control API.

This project was built and tested on a **Raspberry Pi 1** with a **Yamaha R-N803D**.

The guide below starts from a normal Raspberry Pi OS installation and includes the required packages, so you do not need to install Python or Fauxmo beforehand.

## How it works

```text
Alexa / Echo
    |
    v
Fauxmo on Raspberry Pi
    |
    v
yamaha-on.sh / yamaha-off.sh
    |
    v
yamaha-ip.sh
    |
    +-- cached address (fast path)
    +-- MAC address lookup
    +-- automatic local /24 network scan if needed
    |
    v
Yamaha Extended Control API
    |
    v
Yamaha receiver
```

The Yamaha receiver **does not need a static IP address or DHCP reservation**. The script identifies it by MAC address and obtains its current DHCP address when necessary.

Working commands:

```text
Alexa, turn on Yamaha
Alexa, turn off Yamaha
```

## Before you start

You need:

- Raspberry Pi running Raspberry Pi OS or another Debian-based Linux distribution
- Raspberry Pi connected to the same LAN as the Yamaha receiver and Echo
- Amazon Echo / Alexa
- Yamaha receiver supporting Yamaha Extended Control API
- Network standby enabled on the Yamaha if required by your model
- MAC address of the Yamaha receiver
- Terminal/SSH access to the Raspberry Pi

The tested software combination is Raspberry Pi OS / Raspbian 13 (Trixie), Python 3.13 and Fauxmo 0.8.0.

## 1. Update Raspberry Pi OS and install prerequisites

Run:

```bash
sudo apt update
sudo apt install -y python3 python3-venv python3-pip curl iproute2 iputils-ping
```

Check the important commands:

```bash
python3 --version
curl --version
ip -V
ping -V
```

If all four commands return version information, continue.

`python3-venv` is required for the isolated Python environment. `curl` talks to the Yamaha API, `iproute2` provides `ip neigh`/routing information, and `iputils-ping` is used only when the MAC address is not already present in the neighbour table.

## 2. Create the project directory and Python environment

```bash
mkdir -p ~/fauxmo-yamaha
cd ~/fauxmo-yamaha
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install fauxmo==0.8.0
```

Verify Fauxmo:

```bash
fauxmo --version
```

If your Fauxmo build does not implement `--version`, verify the installed package instead:

```bash
python3 -m pip show fauxmo
```

The output should show:

```text
Version: 0.8.0
```

This project intentionally pins **Fauxmo 0.8.0**. It is the version used by the tested installation and includes support for `initial_state`, which is important for reliable Alexa discovery with fake state.

## 3. Download the bridge files

**You do not need to create the `.sh` files manually or copy their contents from this page.** They are already included in this GitHub repository. The commands below download the complete scripts directly into `~/fauxmo-yamaha`.

Make sure you are in the project directory:

```bash
cd ~/fauxmo-yamaha
```

Download all required bridge files:

```bash
curl -O https://raw.githubusercontent.com/bandarko/Alexa-Yamaha-Bridge/main/yamaha-ip.sh
curl -O https://raw.githubusercontent.com/bandarko/Alexa-Yamaha-Bridge/main/yamaha-on.sh
curl -O https://raw.githubusercontent.com/bandarko/Alexa-Yamaha-Bridge/main/yamaha-off.sh
curl -o config.json https://raw.githubusercontent.com/bandarko/Alexa-Yamaha-Bridge/main/config.example.json
```

What these files do:

- **`yamaha-ip.sh`** - finds the Yamaha receiver on your LAN by its MAC address and returns its current IP address. It also caches the last working address for faster operation.
- **`yamaha-on.sh`** - calls `yamaha-ip.sh` to find the receiver and then sends the Yamaha Extended Control API power ON command.
- **`yamaha-off.sh`** - calls `yamaha-ip.sh` to find the receiver and then sends the Yamaha Extended Control API standby/OFF command.
- **`config.json`** - tells Fauxmo which local scripts to execute when Alexa sends ON or OFF.

Check that the files were downloaded:

```bash
ls -la ~/fauxmo-yamaha
```

You should see at least:

```text
yamaha-ip.sh
yamaha-on.sh
yamaha-off.sh
config.json
.venv
```

Make the three shell scripts executable:

```bash
chmod +x ~/fauxmo-yamaha/yamaha-ip.sh \
         ~/fauxmo-yamaha/yamaha-on.sh \
         ~/fauxmo-yamaha/yamaha-off.sh
```

At this point the scripts already contain all required code. **Do not create new empty `.sh` files.** The only script you need to edit is `yamaha-ip.sh`, in the next step, to enter your Yamaha's MAC address.

## 4. Enter your Yamaha MAC address

Open the already-downloaded discovery script:

```bash
nano ~/fauxmo-yamaha/yamaha-ip.sh
```

Find this line near the top:

```bash
YAMAHA_MAC="aa:bb:cc:dd:ee:ff"
```

Replace only `aa:bb:cc:dd:ee:ff` with the MAC address of your Yamaha receiver, keeping the quotation marks.

Example format only:

```bash
YAMAHA_MAC="12:34:56:78:9a:bc"
```

Do not change the rest of the script.

Save with `Ctrl+O`, press Enter, then exit nano with `Ctrl+X`.

No Yamaha IP address needs to be configured.

## 5. Test automatic Yamaha discovery

Run:

```bash
~/fauxmo-yamaha/yamaha-ip.sh
```

Expected result: one IPv4 address, for example:

```text
192.168.1.37
```

The exact address does not matter and may change later.

The script first tries its cached last-known address. If that fails, it looks for the configured MAC address in the Linux neighbour table. If necessary, it automatically determines the Raspberry Pi's local `/24` network, performs a short ping sweep to populate the neighbour table, finds the Yamaha by MAC address, and confirms that Yamaha's `getDeviceInfo` API responds.

If discovery fails, verify the MAC address, make sure the Yamaha is powered or available through network standby, and confirm that the Raspberry Pi and Yamaha are on the same local network.

## 6. Test the Yamaha API directly

Store the discovered address:

```bash
YAMAHA_IP=$(~/fauxmo-yamaha/yamaha-ip.sh)
echo "$YAMAHA_IP"
```

Check device information:

```bash
curl "http://$YAMAHA_IP/YamahaExtendedControl/v1/system/getDeviceInfo"
```

Then test power control.

Power ON:

```bash
curl "http://$YAMAHA_IP/YamahaExtendedControl/v1/main/setPower?power=on"
```

Standby/OFF:

```bash
curl "http://$YAMAHA_IP/YamahaExtendedControl/v1/main/setPower?power=standby"
```

A successful power request should contain:

```json
{"response_code":0}
```

Do not continue until both commands control the receiver correctly.

## 7. Test the bridge scripts

Power ON:

```bash
~/fauxmo-yamaha/yamaha-on.sh
```

Power OFF/standby:

```bash
~/fauxmo-yamaha/yamaha-off.sh
```

Both scripts call `yamaha-ip.sh` first, so they continue to work if DHCP later gives the Yamaha another IP address.

## 8. Configure Fauxmo

Find your Raspberry Pi username:

```bash
whoami
```

Open the configuration:

```bash
nano ~/fauxmo-yamaha/config.json
```

Replace every occurrence of `YOUR_PI_USER` with the username printed by `whoami`.

The finished configuration should look like this, with your own username in the paths:

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

`use_fake_state` lets Fauxmo remember the latest successful Alexa action. `initial_state` gives Alexa a valid initial state during discovery.

## 9. Test Fauxmo in the foreground

Activate the virtual environment and start Fauxmo:

```bash
cd ~/fauxmo-yamaha
source .venv/bin/activate
fauxmo -c ~/fauxmo-yamaha/config.json -v
```

Leave this terminal running temporarily.

In another terminal, confirm port 12340 is listening:

```bash
ss -lntp | grep 12340
```

If Fauxmo starts without configuration errors and port 12340 is listening, continue.

## 10. Discover Yamaha in Alexa

With Fauxmo still running, start device discovery in the Alexa app or say:

```text
Alexa, discover devices
```

The new device should appear as **Yamaha**. Alexa may classify the emulated device as a plug or under **Other**; that is normal.

Test:

```text
Alexa, turn on Yamaha
Alexa, turn off Yamaha
```

If Alexa does not find it, restart the Echo and run discovery again. This was required during the original Raspberry Pi 1 setup.

When the voice commands work, stop the foreground Fauxmo process with `Ctrl+C`.

## 11. Install the systemd service

Download the supplied service template:

```bash
sudo curl -o /etc/systemd/system/fauxmo-yamaha.service \
  https://raw.githubusercontent.com/bandarko/Alexa-Yamaha-Bridge/main/fauxmo-yamaha.service.example
```

Find your username again if necessary:

```bash
whoami
```

Edit the service:

```bash
sudo nano /etc/systemd/system/fauxmo-yamaha.service
```

Replace every `YOUR_PI_USER` with your Raspberry Pi username.

Then enable and start it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now fauxmo-yamaha
```

Check status:

```bash
systemctl status fauxmo-yamaha --no-pager
```

Expected status:

```text
Active: active (running)
```

Also check the Fauxmo port:

```bash
ss -lntp | grep 12340
```

## 12. Final reboot test

Reboot the Raspberry Pi:

```bash
sudo reboot
```

After it comes back, reconnect over SSH and check:

```bash
systemctl is-active fauxmo-yamaha
```

Expected:

```text
active
```

Now test both voice commands again:

```text
Alexa, turn on Yamaha
Alexa, turn off Yamaha
```

If they work after the reboot, installation is complete.

## Troubleshooting

Force Yamaha rediscovery by deleting the cached address:

```bash
rm -f /tmp/yamaha-ip
~/fauxmo-yamaha/yamaha-ip.sh
```

Check whether the Yamaha MAC is visible:

```bash
ip neigh
```

Test the ON/OFF scripts without Alexa:

```bash
~/fauxmo-yamaha/yamaha-on.sh
~/fauxmo-yamaha/yamaha-off.sh
```

View the latest service logs:

```bash
journalctl -u fauxmo-yamaha -n 100 --no-pager
```

Restart Fauxmo:

```bash
sudo systemctl restart fauxmo-yamaha
```

Check service state and port:

```bash
systemctl status fauxmo-yamaha --no-pager
ss -lntp | grep 12340
```

If `yamaha-on.sh` and `yamaha-off.sh` work but Alexa does not, concentrate troubleshooting on Fauxmo/Alexa discovery rather than the Yamaha API.

## Tested configuration

- Raspberry Pi 1
- Raspberry Pi OS / Raspbian 13 (Trixie)
- Python 3.13
- Fauxmo 0.8.0
- Yamaha R-N803D
- Yamaha located dynamically by MAC address
- No static Yamaha IP or DHCP reservation
- Fauxmo TCP port 12340
- systemd auto-start

The same Raspberry Pi can run other lightweight services. The original tested Pi also runs Pi-hole and WireGuard.

## Why Fauxmo 0.8.0?

The project deliberately installs:

```bash
python3 -m pip install fauxmo==0.8.0
```

instead of an unpinned `pip install fauxmo`. Version 0.8.0 is the version tested with this bridge, and the Fauxmo 0.8.0 release includes the fix that passes `initial_state` correctly to plugins. Pinning the version also prevents a future Fauxmo release from silently changing the behaviour of an otherwise working installation.

## Optional future features

Yamaha Extended Control API also supports functions such as volume, mute and input selection. They are intentionally outside the current stable version of this project. The goal here is reliable Alexa ON/OFF control with as few moving parts as possible.

## Notes

This is an independent community project and is not affiliated with Yamaha, Amazon or the Fauxmo project.
