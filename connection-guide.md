# HAMNET Connection Guide

## Requirements

- Amateur radio license
- HAMNET account: [hamnetdb.net](https://hamnetdb.net)
- Directional antenna, 2.3 GHz, 15+ dBi, line of sight to node

## Find Your Node

Check [hamnetdb.net/map.cgi](https://hamnetdb.net/map.cgi) — note the frequency, channel width, and SSID.
Hungarian nodes typically use **2362 MHz, 5 MHz**.

---

## Passive RX (monitor mode)

```sh
iw phy phy0 interface add mon0 type monitor
ip link set mon0 up
iw dev mon0 set freq 2362
iw dev mon0 survey dump | grep -A5 "2362"
tcpdump -i mon0 -e -s 200 type mgt subtype beacon
```

---

## Connect (station mode)

```sh
uci set wireless.radio0.frequency='2362'
uci set wireless.radio0.chanbw='5'
uci set wireless.default_radio0.mode='sta'
uci set wireless.default_radio0.ssid='<SSID>'
uci set wireless.default_radio0.encryption='none'
uci set wireless.radio0.disabled='0'
uci commit wireless
wifi reload
```

Verify:
```sh
iw dev wlan0 link
logread | tail -10
```

---

## PPPoE Login

```sh
cat > /tmp/wpa.conf << 'EOF'
ctrl_interface=/var/run/wpa_supplicant
network={
    ssid="<SSID>"
    key_mgmt=NONE
    freq_list=2362
}