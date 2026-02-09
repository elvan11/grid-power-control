# SolisCloud Platform API V2.0.2 — Device APIs (Part 2)

## 3.5 Obtain Daily Data of a Single Inverter for a Month
**URL:** `https://www.soliscloud.com:13333/v1/api/inverterMonth`

**Description:** Retrieves daily energy production data for a single inverter during a specific month.

**Rate limit:** 2 requests/second

### Request Body
| Parameter | Type | Required | Description |
|------------|------|-----------|-------------|
| id | Integer | N | Inverter ID (required if `sn` is empty) |
| sn | String | N | Serial number |
| time | String | Y | Month, format: `yyyy-MM` |
| timeZone | Integer | Y | Time zone offset (e.g. 8 for UTC+8) |

### Example Request
```json
{
  "id": "1308675217944611083",
  "sn": "120B40198150131",
  "time": "2023-06",
  "timeZone": 8
}
```

### Example Response
```json
{
  "success": true,
  "code": "0",
  "msg": "success",
  "data": [
    { "time": "2023-06-01", "eToday": 48.5 },
    { "time": "2023-06-02", "eToday": 47.9 }
  ]
}
```

---

## 3.6 Obtain Monthly Data of a Single Inverter for a Year
**URL:** `https://www.soliscloud.com:13333/v1/api/inverterYear`

**Description:** Retrieves total monthly energy production for a given inverter across a specific year.

### Request Body
| Parameter | Type | Required | Description |
|------------|------|-----------|-------------|
| id | Integer | N | Inverter ID |
| sn | String | N | Serial number |
| year | String | Y | Year (e.g. `2023`) |
| timeZone | Integer | Y | Time zone offset |

### Example Response
```json
{
  "success": true,
  "code": "0",
  "msg": "success",
  "data": [
    { "month": "2023-01", "eMonth": 1234.56 },
    { "month": "2023-02", "eMonth": 1100.12 }
  ]
}
```

---

## 3.7 Obtain Annual Data of a Single Inverter
**URL:** `https://www.soliscloud.com:13333/v1/api/inverterTotal`

**Description:** Retrieves annual aggregated production per year for one inverter.

### Example Response
```json
{
  "success": true,
  "code": "0",
  "msg": "success",
  "data": [
    { "year": 2022, "eYear": 13400.2 },
    { "year": 2023, "eYear": 13800.5 }
  ]
}
```

---

## 3.8 Obtain Quality Assurance Data for Multiple Inverters
**URL:** `https://www.soliscloud.com:13333/v1/api/inverterQuality`

**Description:** Returns warranty and service data for inverters under the account.

### Response Example
```json
{
  "success": true,
  "data": [
    {
      "sn": "120B40198150131",
      "stationId": "1298491919448631809",
      "warrantyEnd": "2027-12-31",
      "status": "Valid"
    }
  ]
}
```

---

## 3.9 Obtain Device Alarm List Under Account
**URL:** `https://www.soliscloud.com:13333/v1/api/deviceAlarmList`

**Description:** Retrieves alarm logs for all devices under an account.

### Request Body
| Parameter | Type | Required | Description |
|------------|------|-----------|-------------|
| pageNo | Integer | Y | Page number |
| pageSize | Integer | Y | Number of records per page |
| sn | String | N | Specific device SN |

### Response Example
```json
{
  "data": [
    {
      "sn": "120B40198150131",
      "alarmCode": "A01",
      "alarmDesc": "Grid Overvoltage",
      "time": "2023-06-27T12:40:00Z"
    }
  ]
}
```

---

## 3.10 Obtain Collector List Under Account
**URL:** `https://www.soliscloud.com:13333/v1/api/collectorList`

**Description:** Retrieves all data loggers (collectors) bound to an account.

### Response Example
```json
{
  "data": [
    {
      "collectorSn": "404314859",
      "model": "S4-WIFI-ST",
      "stationId": "1298491919448631809",
      "status": "Online"
    }
  ]
}
```

---

## 3.11 Obtain Details of a Single Collector
**URL:** `https://www.soliscloud.com:13333/v1/api/collectorDetail`

### Example Response
```json
{
  "data": {
    "collectorSn": "404314859",
    "model": "S4-WIFI-ST",
    "firmware": "v1.12",
    "signal": 78,
    "ip": "192.168.1.50"
  }
}
```

---

## 3.12 Obtain Collector Signal Values
**URL:** `https://www.soliscloud.com:13333/v1/api/collectorSignal`

**Description:** Returns current signal quality and connection metrics.

```json
{
  "data": {
    "collectorSn": "404314859",
    "signalStrength": 82,
    "lastHeartbeat": "2023-06-27T10:45:00Z"
  }
}
```

---

## 3.13 Obtain EPM List Under Account
**URL:** `https://www.soliscloud.com:13333/v1/api/epmList`

**Description:** Lists all Energy Power Meters (EPM) under the account.

```json
{
  "data": [
    { "epmSn": "20025543400", "stationId": "1298491919448631809", "status": "Online" }
  ]
}
```

---

## 3.14 Obtain Details of a Single EPM
**URL:** `https://www.soliscloud.com:13333/v1/api/epmDetail`

```json
{
  "data": {
    "epmSn": "20025543400",
    "voltage": 230.2,
    "current": 10.5,
    "power": 2.4,
    "energyToday": 25.6
  }
}
```

---

## 3.15 Obtain Real-Time Data of an EPM (Specific Day)
**URL:** `https://www.soliscloud.com:13333/v1/api/epmDay`

```json
{
  "data": [
    { "time": "2023-06-27 09:00", "power": 2.3, "energy": 25.6 }
  ]
}
```

---

## 3.16 Obtain Daily Data of a Single EPM for a Month
**URL:** `https://www.soliscloud.com:13333/v1/api/epmMonth`

```json
{
  "data": [
    { "date": "2023-06-01", "energy": 42.6 },
    { "date": "2023-06-02", "energy": 43.1 }
  ]
}
```

---

## 3.17 Obtain Monthly Data of a Single EPM for a Year
**URL:** `https://www.soliscloud.com:13333/v1/api/epmYear`

```json
{
  "data": [
    { "month": "2023-01", "energy": 1200.3 },
    { "month": "2023-02", "energy": 1154.7 }
  ]
}
```

---

## 3.18 Obtain Annual Data for a Single EPM
**URL:** `https://www.soliscloud.com:13333/v1/api/epmTotal`

```json
{
  "data": [
    { "year": 2022, "energy": 14500.0 },
    { "year": 2023, "energy": 15200.4 }
  ]
}
```

---

## 3.19 Obtain Meteorological Instrument List
**URL:** `https://www.soliscloud.com:13333/v1/api/weatherList`

```json
{
  "data": [
    { "deviceSn": "MET001", "stationId": "1298491919448631809", "status": "Online" }
  ]
}
```

---

## 3.20 Obtain Details of a Meteorological Instrument
**URL:** `https://www.soliscloud.com:13333/v1/api/weatherDetail`

```json
{
  "data": {
    "temperature": 24.6,
    "irradiance": 865.3,
    "windSpeed": 2.3,
    "humidity": 51
  }
}
```

---

## 3.21 Obtain Meter List Under Account
**URL:** `https://www.soliscloud.com:13333/v1/api/meterList`

```json
{
  "data": [
    { "meterSn": "MTR202301", "stationId": "1298491919448631809", "type": "CT Meter" }
  ]
}
```

---

## 3.22 Obtain Details of a Single Meter
**URL:** `https://www.soliscloud.com:13333/v1/api/meterDetail`

```json
{
  "data": {
    "meterSn": "MTR202301",
    "voltage": 230.1,
    "current": 12.5,
    "power": 2.8,
    "energyToday": 24.5,
    "energyTotal": 1567.9
  }
}
```

---

_End of Part 2 — Next: Plant Interfaces (Part 3)_

