# HAMNET Connection Guide

How to connect a client to a HAMNET AP, change frequency, and (untested) notes on
10 MHz operation.

> **Legal notice:** Use of the 2300–2400 MHz band requires a valid amateur radio
> license.

---

## Channel ↔ frequency map

The HAMNET chantable (patch 003) remaps channel numbers to 2312–2377 MHz in
5 MHz steps. Use this table when picking a channel.

Formula: `frequency = 2312 + (channel - 1) * 5`

| Channel | Frequency | Channel | Frequency |
|---|---|---|---|
| 1 | 2312 MHz | 8 | 2347 MHz |
| 2 | 2317 MHz | 9 | 2352 MHz |
| 3 | 2322 MHz | 10 | 2357 MHz |
| 4 | 2327 MHz | 11 | 2362 MHz |
| 5 | 2332 MHz | 12 | 2367 MHz |
| 6 | 2337 MHz | 13 | 2372 MHz |
| 7 | 2342 MHz | 14 | 2377 MHz |

---

## Basic connection (5 MHz, default)

The client scans the HAMNET band and associates with the matching SSID. The
`freq_list` tells the supplicant which frequencies to scan; `chanbw '5'` selects
quarter-rate width.

```sh
uci set wireless.radio0.channel='auto'
uci set wireless.radio0.chanbw='5'
uci set wireless.radio0.country='00'
uci set wireless.radio0.disabled='0'

uci set wireless.sta.mode='sta'
uci set wireless.sta.ssid='HAMNET-DEMO'
uci set wireless.sta.encryption='none'
uci set wireless.sta.network='wwan'
uci set wireless.sta.freq_list='2312 2317 2322 2327 2332 2337 2342 2347 2352 2357 2362 2367 2372 2377'

uci commit wireless
wifi
```

Verify:

```sh
iw dev wlan0 link
```

Expected:

```
Connected to <AP-BSSID> (on wlan0)
        SSID: HAMNET-DEMO
        freq: 2362
        tx bitrate: 1.0 MBit/s
```

---

## Connecting on a specific frequency

If you know the AP's frequency, narrow the `freq_list` to just that value. This
speeds up association (the supplicant doesn't sweep the whole band) and avoids
locking onto the wrong AP.

Example — connect only on 2362 MHz:

```sh
uci set wireless.sta.freq_list='2362'
uci commit wireless
wifi
```

You can also list a few candidate frequencies if the AP might be on one of them:

```sh
uci set wireless.sta.freq_list='2357 2362 2367'
uci commit wireless
wifi
```

> Only frequencies present in the chantable (2312–2377 MHz) are valid. Listing a
> frequency outside this range causes SCAN-FAILED, because the kernel has no such
> channel registered.

---

## Connecting to a specific SSID / AP

Change the SSID to match the target AP:

```sh
uci set wireless.sta.ssid='YOUR-AP-SSID'
uci commit wireless
wifi
```

If multiple APs share an SSID and you want a specific one, pin the BSSID:

```sh
uci set wireless.sta.bssid='c4:6e:1f:b2:b3:ac'
uci commit wireless
wifi
```

---

## 10 MHz (half-rate) operation — UNTESTED

> **Note:** 10 MHz operation has **not been tested**. The receive-side fix
> (patch 009) already covers `NL80211_BSS_CHAN_WIDTH_10`, so the beacon-channel
> handling should work, but the other layers (driver quarter/half force in patch
> 006, the connect-side width in patch 008, and the chantable in patch 003) are
> built and verified for 5 MHz only. Expect to extend those before 10 MHz works.

What is already in place for 10 MHz:

- The kernel `cfg80211_get_bss_channel` fix (009) returns the RX channel for
  `WIDTH_10` as well as `WIDTH_5`, so received beacons on half-rate channels are
  not dropped for the channel-number mismatch reason.
- The driver maps `chan_bw == 10` to `NL80211_CHAN_WIDTH_10` →
  `CHANNEL_HALF` in `ath9k_cmn_update_ichannel` (stock behaviour).

What would likely need changes for 10 MHz:

- **Patch 006** currently forces `CHANNEL_QUARTER` (5 MHz) for the whole HAMNET
  range. For 10 MHz you would need a half-rate path instead of, or alongside, the
  quarter-rate force — otherwise the driver is pinned to 5 MHz regardless of
  config.
- **Patch 008** adds `NL80211_CHAN_WIDTH_5` to the connect message for HAMNET
  frequencies. A 10 MHz AP would need `NL80211_CHAN_WIDTH_10` on the connect
  side.
- **Patch 003** chantable frequencies are laid out for 5 MHz steps; a 10 MHz plan
  may use a different frequency spacing.

A starting config to try (will not work without the patch changes above):

```sh
uci set wireless.radio0.chanbw='10'
uci set wireless.sta.chanbw='10'
uci commit wireless
wifi
```

Then watch what the driver and supplicant report:

```sh
logread | grep -E "CHANNEL_HALF|WIDTH_10|HAMNET|Trying|Associat"
iw dev wlan0 link
```

If the link does not come up, the bisection method in the patch guide
(`mon0` rx_packets → rx_errors → get_channel → scan_width → bss_channel) applies
the same way it did for 5 MHz.

---

## Troubleshooting quick reference

| Symptom | Likely cause | Where to look |
|---|---|---|
| `SCAN-FAILED ret=-22` | freq_list contains a frequency not in chantable | keep freq_list within 2312–2377 |
| `Not connected`, scan runs forever | beacon received but not registered | `dmesg \| grep HAMNET-DBG`, check `bss_channel` |
| `Resource busy (-16)` | netifd and a manual supplicant fighting for wlan0 | let netifd manage it; avoid manual `wpa_supplicant` |
| No `scan_freq` in generated config | patch 007 not applied | `cat /var/run/wpa_supplicant-wlan0.conf` |
| AP transmits 20 MHz instead of 5 | `chanbw '5'` missing on AP | check AP `/etc/config/wireless` |

A clean restart, letting netifd bring up the station, is usually the most reliable
recovery:

```sh
wifi down
sleep 3
wifi up
sleep 15
iw dev wlan0 link
```