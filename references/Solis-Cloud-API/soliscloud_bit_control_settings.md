# SolisCloud — Bit Control Settings

## Overview

Bit control settings are used with **CID 636** (Storage Inverters Control Switching) to manage multiple operational modes simultaneously. Each bit represents a distinct control option that can be toggled independently.

---

## Bit Control Table

| Bit | Description | Values |
|-----|--------------|---------|
| BIT00 | Self-Use mode switch | `0 — OFF`, `1 — ON` |
| BIT01 | Time of Use switch | `0 — OFF`, `1 — ON` |
| BIT02 | Off-Grid mode switch | `0 — OFF`, `1 — ON` |
| BIT03 | Battery wake-up switch *(1 = enabled, 0 = not enabled)* | `0 — OFF`, `1 — ON` |
| BIT04 | Back-up mode switch | `0 — OFF`, `1 — ON` |
| BIT05 | Allow/disallow charging of batteries from the grid | `0 — NOT ALLOWED`, `1 — ALLOWED` |
| BIT06 | Feed-In priority mode switch | `0 — OFF`, `1 — ON` |
| BIT07 | Night battery over-discharge hold switch | `0 — OFF`, `1 — ON` |
| BIT08 | Dynamic regulation enable switch when battery is force charged from grid | `0 — OFF`, `1 — ON` |
| BIT09 | Battery current correction enable switch | `0 — OFF`, `1 — ON` |
| BIT10 | Battery treatment mode | `0 — OFF`, `1 — ON` |
| BIT11 | Peak-shaving mode switch | `0 — OFF`, `1 — ON` |

---

## Usage

### Binary Assembly

Binary assembly of all bits:  
**BIT15** is the **first bit on the left** and is set to **1** if you want to turn it on.

To form the command:
1. Combine the bits into a binary sequence (16 bits total).
2. Convert the binary to **decimal**.
3. Send the **decimal value** as the input parameter to CID 636.

### Bit Position Reference

```
Bit Position (left to right):
BIT15 BIT14 BIT13 BIT12 BIT11 BIT10 BIT09 BIT08 BIT07 BIT06 BIT05 BIT04 BIT03 BIT02 BIT01 BIT00
  0     0     0     0     0     0     0     0     0     0     0     0     0     0     0     0
```

---

## Examples

### Example 1: Turn on BIT05 (Allow Grid Charging)

**Goal:** Enable battery charging from the grid.

```
Binary (right to left):
BIT00-BIT04: 0
BIT05: 1 (Allow grid charging)
BIT06-BIT15: 0

Bit sequence: 0000 0000 0010 0000
Decimal: 32
```

**API Payload:**
```json
{
  "cid": "636",
  "inverterSn": "xxxx",
  "value": "32",
  "yuanzhi": "[current_value]",
  "language": "2"
}
```

---

### Example 2: Turn on BIT06 and BIT04, Keep BIT05 Off

**Goal:** Enable Feed-In Priority mode and Back-up mode, but disallow grid charging.

```
Binary (right to left):
BIT00-BIT03: 0
BIT04: 1 (Back-up mode)
BIT05: 0 (Disallow grid charging)
BIT06: 1 (Feed-In priority mode)
BIT07-BIT15: 0

Bit sequence: 0000 0000 0101 0000
Decimal: 80
```

**API Payload:**
```json
{
  "cid": "636",
  "inverterSn": "xxxx",
  "value": "80",
  "yuanzhi": "[current_value]",
  "language": "2"
}
```

---

### Example 3: Enable Self-Use Mode (BIT00) + Time of Use (BIT01)

**Goal:** Turn on both Self-Use and Time of Use modes.

```
Binary (right to left):
BIT00: 1 (Self-Use mode)
BIT01: 1 (Time of Use)
BIT02-BIT15: 0

Bit sequence: 0000 0000 0000 0011
Decimal: 3
```

**API Payload:**
```json
{
  "cid": "636",
  "inverterSn": "xxxx",
  "value": "3",
  "yuanzhi": "[current_value]",
  "language": "2"
}
```

---

### Example 4: Off-Grid Mode with Battery Wake-up

**Goal:** Enable Off-Grid mode and Battery wake-up.

```
Binary (right to left):
BIT02: 1 (Off-Grid mode)
BIT03: 1 (Battery wake-up)
Others: 0

Bit sequence: 0000 0000 0000 1100
Decimal: 12
```

**API Payload:**
```json
{
  "cid": "636",
  "inverterSn": "xxxx",
  "value": "12",
  "yuanzhi": "[current_value]",
  "language": "2"
}
```

---

## Decimal Conversion Quick Reference

| Configuration | Binary | Decimal |
|---------------|--------|---------|
| BIT00 only | 0000000000000001 | 1 |
| BIT01 only | 0000000000000010 | 2 |
| BIT00 + BIT01 | 0000000000000011 | 3 |
| BIT02 only | 0000000000000100 | 4 |
| BIT03 only | 0000000000001000 | 8 |
| BIT04 only | 0000000000010000 | 16 |
| BIT05 only | 0000000000100000 | 32 |
| BIT06 only | 0000000001000000 | 64 |
| BIT07 only | 0000000010000000 | 128 |
| BIT08 only | 0000000100000000 | 256 |
| BIT09 only | 0000001000000000 | 512 |
| BIT10 only | 0000010000000000 | 1024 |
| BIT11 only | 0000100000000000 | 2048 |

---

## Implementation Notes

### Reading Before Writing

Before sending a CID 636 command, always:
1. Use the "atread" interface or a GET request to read the **current value**.
2. Calculate your desired configuration based on the current state.
3. Set the `yuanzhi` field to the **current value** you just read.
4. Send the command with the new `value` and the `yuanzhi` field.

**Example:**
```json
{
  "cid": "636",
  "inverterSn": "xxxx",
  "value": "80",
  "yuanzhi": "5",
  "language": "2"
}
```

Here, `yuanzhi: "5"` means the inverter's previous state was decimal 5 (BIT00 and BIT02 were on).

### Bit Manipulation in Code

If implementing bit control in Home Assistant or Python, use bitwise operations:

```python
# Define bit positions
BIT_SELF_USE = 0          # 1 << 0 = 1
BIT_TIME_OF_USE = 1       # 1 << 1 = 2
BIT_OFF_GRID = 2          # 1 << 2 = 4
BIT_BATTERY_WAKEUP = 3    # 1 << 3 = 8
BIT_BACKUP = 4            # 1 << 4 = 16
BIT_GRID_CHARGE = 5       # 1 << 5 = 32
BIT_FEED_IN_PRIORITY = 6  # 1 << 6 = 64
BIT_NIGHT_HOLD = 7        # 1 << 7 = 128

# Turn on Self-Use and Time of Use
value = (1 << BIT_SELF_USE) | (1 << BIT_TIME_OF_USE)
# Result: 1 | 2 = 3

# Check if a bit is set
current_value = 5
is_self_use_on = (current_value & (1 << BIT_SELF_USE)) != 0
# Result: True (BIT00 is set in 5)
```

### Error Handling

If a command fails with an error mentioning `yuanzhi`:
- The inverter's state may have changed since you last read it.
- Re-read the current value using "atread".
- Retry the command with the updated `yuanzhi` value.
- Implement a retry mechanism with exponential backoff for transient failures.

---

## Related Documentation

- **Control API:** See `soliscloud_device_control_api_v_2.md` for CID 636 specifications.
- **Command List:** See `soliscloud_command_list.md` for CID reference.
- **Control Examples:** See `soliscloud_control_examples.md` for practical use cases.

