# SolisCloud Platform API Document V2.0.2

## 1. Global Description
- All interfaces use HTTPS encryption.
- Data update frequency: every 5 minutes.
- All requests use the POST method.
- Content type: `application/json; charset=UTF-8`.
- Each request must include headers: `Content-MD5`, `Content-Type`, `Date`, and `Authorization`.
- All responses are in JSON format.
- Units (power, energy, frequency, etc.) must be interpreted with their associated measurement unit.

---

## 2. Interface Information

### 2.1 Interface Address and Key
| Type | Content |
|------|----------|
| API URL | `https://www.soliscloud.com:13333/` |
| API ID | Obtain from SolisCloud portal under **Account → Basic Settings → API Management** |
| API Secret | Used for signature generation |

### 2.2 Request Standard Format
```
POST [API URL]
Content-MD5: [Content-MD5]
Content-Type: application/json;charset=UTF-8
Date: [Date]
Authorization: API {apiId}: [sign]
Body: [Body]
```

#### Example
```json
{
  "id": "1308675217944611083",
  "sn": "120B40198150131"
}
```

**Authorization Signature Formula:**
```
Sign = base64(HmacSHA1(apiSecret,
    POST + "\n" + Content-MD5 + "\n" + Content-Type + "\n" + Date + "\n" + CanonicalizedResource))
```

### 2.3 Standard Response Format
```json
{
  "success": true,
  "code": "0",
  "msg": "success",
  "data": {}
}
```

### 2.4 Interface Call Example
```
POST /v1/api/userStationList
Content-MD5: kxdxk7rbAsrzSIWgEwhH4w==
Content-Type: application/json
Date: Fri, 26 Jul 2019 06:00:46 GMT
Authorization: API {apiId}:nBYQWeuzy3Y+gp67BN8zXTmvSDk=
Body: {"pageNo":1,"pageSize":10}
```

### 2.5 Encryption Tool Reference
- **Java Authorization Example:** [Authorization.java](https://ginlong-product.oss-cn-shanghai.aliyuncs.com/templet/Authorization.java)
- **MD5/HMAC Tool:** [https://dinochiesa.github.io/hmachash/index.html](https://dinochiesa.github.io/hmachash/index.html)

---

## 3. Device Interfaces

### 3.1 Obtain Inverter List
**URL:** `https://www.soliscloud.com:13333/v1/api/inverterList`  
**Rate limit:** 2 requests/second

#### Request Body
| Parameter | Type | Required | Description |
|------------|------|-----------|-------------|
| pageNo | String | Y | Page number (default 1) |
| pageSize | String | Y | Items per page (max 100) |
| stationId | Integer | N | Filter by power station ID |
| nmiCode | String | N | Filter by NMI code (for Australian region) |
| snList | Array | N | Filter by inverter serial numbers |

#### Response Example
```json
{
  "success": true,
  "code": "0",
  "msg": "success",
  "data": {
    "inverterStatusVo": {
      "all": 8,
      "normal": 0,
      "fault": 0,
      "offline": 8
    },
    "page": {
      "records": [
        {
          "id": "1308675217944611083",
          "sn": "120B40198150131",
          "stationId": "1298491919448631809",
          "productModel": "b4",
          "state": 1,
          "etoday": 27.8,
          "etotal": 36.397,
          "pac": 5.025,
          "collectorSn": "404314859",
          "dataTimestamp": "1687846773000"
        }
      ]
    }
  }
}
```

---

### 3.2 Obtain Inverter Details
**URL:** `https://www.soliscloud.com:13333/v1/api/inverterDetail`  
**Rate limit:** 2 requests/second

#### Request Body
| Parameter | Type | Required | Description |
|------------|------|-----------|-------------|
| id | Integer | Y | Inverter ID or SN |
| sn | String | Y | Inverter serial number |

#### Example Response
```json
{
  "success": true,
  "code": "0",
  "msg": "success",
  "data": {
    "power": 8.0,
    "pac": 5.025,
    "etoday": 27.8,
    "etotal": 36.397,
    "batteryPower": 0.0,
    "batteryCapacitySoc": 0.0,
    "gridSellTodayEnergy": 0.0,
    "familyLoadPower": 0.0,
    "timeZoneStr": "UTC-9:00"
  }
}
```

---

### 3.3 Obtain Multiple Inverter Details
**URL:** `https://www.soliscloud.com:13333/v1/api/inverterDetailList`  
**Rate limit:** 2 requests/second

#### Request Body
| Parameter | Type | Required | Description |
|------------|------|-----------|-------------|
| pageNo | Integer | N | Page number |
| pageSize | Integer | Y | Items per page (max 100) |
| snList | Array | N | List of inverter SNs |

#### Response Example
```json
{
  "success": true,
  "code": "0",
  "msg": "success",
  "data": {
    "records": [
      {
        "id": "1308675217944612385",
        "sn": "00FFFC445594901",
        "state": 2,
        "pac": 21.046,
        "etoday": 750.6,
        "eMonth": 5.693,
        "eYear": 92.996,
        "eTotal": 102.293,
        "fac": 50.0,
        "timeZoneStr": "UTC+08:00"
      }
    ]
  }
}
```

---

### 3.4 Obtain Real-Time Data (Single Inverter, by Day)
**URL:** `https://www.soliscloud.com:13333/v1/api/inverterDay`

#### Request Body
| Parameter | Type | Required | Description |
|------------|------|-----------|-------------|
| id | Integer | N | Inverter ID or SN (required if SN missing) |
| sn | String | N | Inverter serial number |
| money | String | Y | Currency (e.g., EUR, CNY) |
| time | String | Y | Date (format: yyyy-MM-dd) |
| timeZone | Integer | Y | Time zone offset |

#### Response Example
```json
{
  "success": true,
  "code": "0",
  "msg": "success",
  "data": [
    {
      "timeStr": "2023-06-27 05:01:31",
      "acOutputType": 1,
      "dcInputType": 3,
      "pac": 74.0,
      "eToday": 0.0,
      "eTotal": 36362.0,
      "uPv1": 245.3,
      "iPv1": 0.1
    }
  ]
}
```

---

## Appendix 1: Error Codes
| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | Failure |
| Z0001 | Login expired |
| Z0002 | Invalid MD5 checksum |
| 403 | No permissions |
| 429 | Too frequent requests |
| B0107 | Collector model not supported |
| B0124 | Device SN does not exist |
| B0157 | Request timeout (5 min) |

---

## Appendix 2: Power Plant Types
| Type | Description |
|-------|--------------|
| 1 | Ground-mounted PV |
| 2 | Rooftop PV |
| 3 | Floating PV |

---

## Appendix 3: Inverter Meter Types
| ID | Type |
|----|------|
| 1 | Standard inverter |
| 2 | Hybrid inverter |
| 3 | Battery inverter |

