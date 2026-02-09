# SolisCloud API Control Examples

This document provides practical examples for controlling Solis inverters via the SolisCloud API v2. Each example includes the payload structure, parameters, and implementation notes.

**Reference:** These examples follow the patterns documented in `soliscloud_device_control_api_v_2.md` and use the signing helper to generate required authentication headers.

---

## 1. Control Grid-Tied Inverters to Switch On/Off

**Description:** Turn a grid-tied inverter on or off using CID 48.

**Parameters:**
- `cid`: 48 (On command with value 190, or use CID 53 with value 222 for Off)
- `value`: "190" (On) or "222" (Off)

**Payload Example:**

```json
{
  "cid": "48",
  "inverterSn": "xxxx",
  "value": "190",
  "language": "2"
}
```

**Notes:**
- Use CID 53 with value "222" to switch off the inverter.
- Language "2" = English.

---

## 2. Control Hybrid Inverter Power Output Limit

**Description:** Set the inverter to limit power output to a percentage of rated capacity (e.g., 80%).

**Parameters:**
- `cid`: 376 (Inverter Max Output Power Setting)
- `value`: Percentage (0–100)

**Payload Example:**

```json
{
  "cid": "376",
  "inverterSn": "xxxx",
  "value": "80",
  "language": "2"
}
```

**Notes:**
- Value represents the percentage limit relative to inverter rated power.
- Useful for load management and grid protection.

---

## 3. Set Inverter System Time to Current Real Time

**Description:** Synchronize the inverter's internal clock with the current system time.

**Parameters:**
- `cid`: 56 (Inverter Time Setting)
- `value`: Current datetime in format `yyyy-MM-dd HH:mm:ss`

**Payload Example:**

```json
{
  "cid": "56",
  "inverterSn": "xxxx",
  "value": "2024-01-25 14:05:20",
  "language": "2"
}
```

**Notes:**
- Ensure the datetime is in UTC or the inverter's configured timezone.
- Critical for time-based automations and logging accuracy.

---

## 4. Set Hybrid Inverter to Time of Use (TOU) Mode

**Description:** Enable Time of Use mode on the hybrid inverter for price-based scheduling.

**Parameters:**
- `cid`: 543 (Time of Use Select; also referred to as CID 100 in some documentation)
- `value`: "1" (Enable)
- `yuanzhi`: "0" (Original/baseline value for read-modify-write)

**Payload Example:**

```json
{
  "cid": "543",
  "inverterSn": "xxxx",
  "value": "1",
  "yuanzhi": "0",
  "language": "2"
}
```

**Notes:**
1. Set the working mode first before enabling TOU.
2. Use the "atread" interface to read the current value before sending this command.
3. The `yuanzhi` (original value) field helps with error handling if the update fails—refer to the error handling documentation for details.
4. After enabling TOU, configure time slots and charge/discharge currents using CID 103 or CID 148.

---

## 5. Set Hybrid Inverter Charging & Discharging Currents with Time Windows

**Description:** Configure battery charging/discharging currents and set specific time windows for force charge and force discharge operations.

**Parameters:**
- `cid`: 103 (Charge and Discharge Settings)
- `value`: Comma-separated values in order:
  1. Charge Current 1 (Amps, 0–100)
  2. Discharge Current 1 (Amps, 0–100)
  3. Charge Time 1 Start (hh:mm)
  4. Charge Time 1 End (hh:mm)
  5. Discharge Time 1 Start (hh:mm)
  6. Discharge Time 1 End (hh:mm)
  7. Charge Current 2 (repeat pattern for slot 2)
  8. ... (continue for slots 2 and 3)

**Payload Example:**

Setting charge current 50A, discharge current 20A with:
- Force charge: 2:00–3:00
- Force discharge: 3:00–4:00

```json
{
  "cid": "103",
  "inverterSn": "xxxx",
  "value": "50,20,02:00-03:00,03:00-04:00,0,0,00:00-00:00,00:00-00:00,0,0,00:00-00:00,00:00-00:00",
  "language": "2"
}
```

**Notes:**
1. Set the working mode first.
2. Voltage and current settings apply to all time periods; they can only be set once per command.
3. Use time slots in 24-hour format (hh:mm).
4. Unused time slots should be set to "0,0,00:00-00:00,00:00-00:00".
5. Up to 3 time periods can be configured per CID 103 command; for more granularity, use CID 148 or CID 6972.

---

## 6. Set Hybrid Inverter to Self-Use Mode

**Description:** Configure the inverter to prioritize self-consumption of solar energy.

**Parameters:**
- `cid`: 636 (Storage Inverters Control Switching—bit-based control)
- `value`: "1" (Enable bit 0 for Self-Use mode)
- `yuanzhi`: "2" (Original value; replace with actual current value from a prior read)

**Payload Example:**

```json
{
  "cid": "636",
  "inverterSn": "xxxx",
  "value": "1",
  "yuanzhi": "2",
  "language": "2"
}
```

**Notes:**
1. Set the working mode first.
2. CID 636 uses bit flags to control multiple modes simultaneously. Refer to `soliscloud_bit_control_settings.md` for detailed bit definitions and decimal conversion:
   - **BIT00**: Self-Use mode (0 = Off, 1 = On)
   - **BIT01**: Time of Use mode
   - **BIT02**: Off-grid mode
   - **BIT05**: Allow/disallow grid charging
   - **BIT06**: Feed-in priority mode
   - (... additional bits for other modes)
3. Before sending this command, use the "atread" interface to read the current value.
4. Replace `yuanzhi` with the actual current value from your last read.
5. Refer to error handling documentation for `yuanzhi` field interpretation.

---

## 7. Set Hybrid Inverter to Feed-in Priority Mode

**Description:** Configure the inverter to prioritize feeding excess energy to the grid.

**Parameters:**
- `cid`: 636 (Storage Inverters Control Switching—bit-based control)
- `value`: Bit field with BIT06 enabled (Feed-in Priority mode)
- `yuanzhi`: Current control value from prior read

**Payload Example:**

```json
{
  "cid": "636",
  "inverterSn": "xxxx",
  "value": "64",
  "yuanzhi": "2",
  "language": "2"
}
```

**Notes:**
1. Set the working mode first.
2. Feed-in Priority uses **BIT06** of CID 636. Adjust the `value` based on your current bit configuration:
   - If only BIT06 should be active: value = 64 (2^6)
   - If combining with other bits, calculate the sum of active bit values.
3. Before sending this command, use "atread" to read the current control value.
4. This mode maximizes grid feed-in while maintaining SOC guardrails.

---

## 8. Set Hybrid Inverter to Off-Grid Mode

**Description:** Configure the inverter to operate in off-grid/backup mode, powering critical loads from battery.

**Parameters:**
- `cid`: 636 (Storage Inverters Control Switching—bit-based control)
- `value`: Bit field with BIT02 enabled (Off-Grid mode)
- `yuanzhi`: Current control value from prior read

**Payload Example:**

```json
{
  "cid": "636",
  "inverterSn": "xxxx",
  "value": "4",
  "yuanzhi": "2",
  "language": "2"
}
```

**Notes:**
1. Set the working mode first.
2. Off-Grid mode uses **BIT02** of CID 636:
   - If only BIT02 should be active: value = 4 (2^2)
   - If combining with other bits (e.g., battery wakeup), calculate the sum accordingly.
3. Before sending this command, use "atread" to read the current control value.
4. Ensure backup loads are properly connected and battery SOC is adequate.
5. The inverter will disconnect from the grid and operate from battery only.

---

## Implementation Notes

### Authentication & Signing

All payloads must be signed with MD5 and HMAC-SHA1 before transmission. Use the Home Assistant `solis_signer` custom component or the Python helper script:

```python
# Pseudocode
body = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
content_md5 = base64.b64encode(md5(body)).decode()
date = format_gmt_now()
canonical = f"POST\n{content_md5}\napplication/json;charset=UTF-8\n{date}\n/v2/api/control"
signature = base64.b64encode(hmac_sha1(api_secret, canonical)).decode()
auth_header = f"API {api_id}:{signature}"
```

### Rate Limiting

- **Minimum interval:** 30–60 seconds between commands to the same inverter.
- **API quota:** Check your SolisCloud account limits; typical plans allow 10,000 calls/month.
- **Backoff strategy:** Implement exponential backoff for 429 (Too Many Requests) responses.

### Error Handling

- If a command fails with an error related to `yuanzhi`, read the current value using "atread" and retry.
- Some commands (e.g., CID 636) require an exact match of the current state bits; partial updates may fail.
- Log all responses for debugging and audit trails.

### Validation Before Deployment

1. Test on a development/test inverter first.
2. Verify time windows and current limits match your system's capabilities.
3. Confirm that mode switches don't conflict (e.g., Self-Use and Feed-in Priority on simultaneously).
4. Monitor the inverter's response logs via SolisCloud or local monitoring systems.

---

## Related Documentation

- **Device Control API:** See `soliscloud_device_control_api_v_2.md` for endpoint specifications and error codes.
- **Command List:** See `soliscloud_command_list.md` for CID reference and valid value ranges.
- **Platform API:** See `soliscloud_platform_api_v_2_0_2.md` for telemetry endpoints (e.g., `inverterDetail`, `inverterDay`).

