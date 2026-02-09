# SolisCloud Platform API V2.0.2 — Appendices (Part 4)

## Appendix 1: Error Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | Failure |
| Z0001 | Login has expired. Please log in again. |
| Z0002 | Content MD5 is incorrect. |
| 403 | No permissions. |
| 429 | Frequent requests. Try again later. |
| I0013 | Account or password error. |
| B0020 | Verification code error. |
| B0053 | Account already bound to third-party. |
| R0004 | Feature is only available to specific customers. Contact support. |
| B0107 | Collector model does not support this function. |
| B0089 | Device does not belong to this power station. |
| B0063 | Device has not yet been registered in the warehouse. |
| B0115 | Command send failed. |
| B0124 | Device SN does not exist. |
| B0157 | Request time exceeds 5 minutes. |
| R0000 | No permissions. |

---

## Appendix 2: Power Plant Types

| Type | Description |
|------|-------------|
| 1 | Ground-mounted photovoltaic (PV) plant |
| 2 | Rooftop PV system |
| 3 | Floating PV installation |
| 4 | Distributed or hybrid solar system |

---

## Appendix 3: Inverter and Meter Types

| ID | Type |
|----|------|
| 1 | Standard grid-tied inverter |
| 2 | Hybrid inverter (battery + grid) |
| 3 | Off-grid inverter |
| 4 | EPM (Energy Power Meter) |
| 5 | CT-based Meter |
| 6 | Smart Meter (with Modbus) |

---

## Appendix 4: Unit and Measurement Definitions

| Field | Unit | Description |
|--------|------|-------------|
| power | kW | Real-time output power |
| energy | kWh | Energy produced or consumed |
| voltage | V | Voltage reading |
| current | A | Current measurement |
| frequency | Hz | Grid frequency |
| temperature | °C | Device or ambient temperature |
| soc | % | Battery state of charge |
| soh | % | Battery state of health |

---

## Appendix 5: Common API Response Structure

All SolisCloud API responses follow the same JSON structure:

```json
{
  "success": true,
  "code": "0",
  "msg": "success",
  "data": { }
}
```

| Field | Type | Description |
|--------|------|-------------|
| success | Boolean | True if the request succeeded |
| code | String | 0 for success, otherwise error code |
| msg | String | Message corresponding to the result |
| data | Object | Data payload (content varies by endpoint) |

---

## Appendix 6: Rate Limits and Best Practices
- Most APIs allow **2 requests/second per endpoint**.
- Exceeding rate limits may return code `429`.
- Always use `HTTPS` and verify API signatures.
- Timestamps must be within ±15 minutes of current GMT.
- For high-frequency polling, use local caching of inverter or plant data.

---

_End of Part 4 — SolisCloud Platform API Documentation Complete._