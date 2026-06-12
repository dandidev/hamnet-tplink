# HAMNET Connection Guide

## Requirements

- Amateur radio license
- Two routers with the HAMNET firmware (for a local link test)

---

## Verify the radio

Check that HAMNET channels are present and tunable:

```sh
iw phy phy0 info | grep "MHz"
```

---

## IBSS (ad-hoc) link

AP mode via hostapd v2.9 does not support sub-2412 MHz channels.
IBSS mode works and is the recommended method for HAMNET point-to-point links.

The BSSID must be identical on both routers, otherwise they will not merge into the same cell.

### Both routers

```sh
iw dev wlan0 del
iw phy phy0 interface add wlan0 type ibss
ip link set wlan0 up
iw dev wlan0 ibss join HAMNET-TEST 2362 5MHz fixed-freq 02:11:22:33:44:55
```

### Assign IP addresses

```sh
# Router A
ip addr add 10.0.0.1/24 dev wlan0

# Router B
ip addr add 10.0.0.2/24 dev wlan0
```

### Verify the link

```sh
# Check the peer is associated
iw dev wlan0 station dump

# Ping across the link
ping 10.0.0.1
```

A `station dump` showing `associated: yes` and a successful ping confirm a working HAMNET data link at 2362 MHz, 5 MHz width.

---

## Monitor mode (passive RX)

To scan for existing HAMNET activity without transmitting:

```sh
iw phy phy0 interface add mon0 type monitor
ip link set mon0 up
iw dev mon0 set freq 2362
iw dev mon0 survey dump | grep -A5 "2362"
tcpdump -i mon0 -e -s 200
```