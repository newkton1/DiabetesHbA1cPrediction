# Friend's Orbi Network — Pending Setup
*Note created: 8 August 2026. Friend returns from holiday in approximately 2 weeks.*

---

## Network Overview

| Device | IP | Notes |
|---|---|---|
| Orbi Router | 10.0.0.1 | NETGEAR, MAC 08:36:c9:e0:20:7a — stock firmware |
| Orbi Satellite | 10.0.0.10 | NETGEAR, MAC 08:36:c9:e0:1b:66 |
| RPi Pi-hole | 10.0.0.50 | MAC b8:27:eb:85:7c:97 — already installed |
| Canon Printer | 10.0.0.2 | MAC 34:9f:7b:fa:3e:4c |
| Apple TV (Living-Room) | 10.0.0.4 | MAC d4:90:9c:d8:99:e0 |
| Apple device (Living-Room-2) | 10.0.0.5 | MAC c0:95:6d:87:ef:b4 |
| iPhone | 10.0.0.6 | MAC 3e:d2:88:1e:76:7b |
| MacBook | 10.0.0.9 | MAC 38:c9:86:4c:84:a3 |
| Daikin AC | TBD | Not yet connected — main pending task |
| Chromecast | TBD | Currently disconnected |

---

## Key Constraint

**Stock Orbi firmware — no custom iptables scripting available.**
Unlike the R7000 running FreshTomato, the Orbi does not expose a firewall script interface. All iptables-level work must be done on the RPi itself.

---

## What Is Already Done

- Pi-hole installed at 10.0.0.50
- Orbi DHCP should hand out 10.0.0.50 as DNS for all clients — **confirm this is set correctly when back**
- UDP DNS bug noted and fixed on separate R7000 router (unrelated, for reference)

---

## TODO When Friend Returns

### 1. Connect and identify Daikin AC
- Connect Daikin to WiFi (preferably the Orbi guest network — see below)
- Open Pi-hole query log and observe which domains the Daikin calls home to
- Known Daikin domains to review:
  - `api.prod.onecta.daikinsecurity.com` — main cloud API, **keep** (needed for app control)
  - `collector.daikin.eu` — telemetry, **consider blocking**
  - `logging.daikin.eu` — telemetry, **consider blocking**
- Block confirmed telemetry domains via Pi-hole custom blocklist

### 2. Orbi guest network — IoT isolation
- Admin UI → Advanced → Guest Network
- Create a separate IoT SSID
- Connect Daikin AC and Chromecast to this guest SSID
- Guest network blocks IoT devices from accessing main LAN devices by default
- This is the equivalent of the br1 VLAN isolation used on the R7000

### 3. DoT blocking via Orbi UI
- Admin UI → Advanced → Security → Block Services
- Add rule: block TCP port 853 outbound (all clients)
- Add rule: block UDP port 853 outbound (all clients)

### 4. Chromecast hardcoded DNS redirect (on RPi)
Chromecast bypasses DHCP DNS and uses 8.8.8.8 directly. Intercept on the RPi:

```bash
iptables -t nat -A PREROUTING -p udp --dport 53 ! -d 10.0.0.50 -j DNAT --to 10.0.0.50:53
iptables -t nat -A PREROUTING -p tcp --dport 53 ! -d 10.0.0.50 -j DNAT --to 10.0.0.50:53
```

Add to `/etc/rc.local` on the RPi (before `exit 0`) to make persistent.

### 5. DoH blocking via Pi-hole
Add these to Pi-hole's blocklist or custom deny list to block DNS-over-HTTPS to hardcoded endpoints:
- 8.8.8.8 (Google)
- 8.8.4.4 (Google)
- 1.1.1.1 (Cloudflare)
- 1.0.0.1 (Cloudflare)

---

## Reference: Why Not Full iptables on Orbi?

Stock Orbi firmware does not provide:
- Firewall script section (no equivalent of FreshTomato's Administration → Scripts)
- SSH access (on standard consumer models)
- Custom DNAT/egress allowlisting

All granular firewall work for this network must go through Pi-hole or the RPi's own iptables — not the Orbi itself.

---

## Connection Tracking Vulnerability Assessment

**Low risk on this network.** No untrusted cloud-connected IoT devices currently present (the Daikin and Chromecast are the only ones, and both will be addressed above). All other devices are Apple, Canon printer, and MacBook — trusted hardware. No equivalent of the Meross switch egress allowlisting needed unless additional IoT devices are added.
