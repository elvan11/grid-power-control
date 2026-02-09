# SolisCloud Platform API Document V2.0

## 1. Global Description
- All interface encryption is based on HTTPS protocol.
- All interface request methods are `POST`.
- All interface request types are `application/json; charset=UTF-8`.
- All interface returned data is in JSON format.

---

## 2. Interface Information

### 2.1 Interface Address and Key
- **API URL:** `https://www.soliscloud.com:13333/`
- **API ID:** Obtain from SolisCloud portal → Account → Basic Settings → API Management.
- **API Secret:** Confidential key for signature generation.

### 2.2 Request Standard Format
```
POST [API URL]
Content-MD5: [Content-MD5]
Content-Type: application/json;charset=UTF-8
Date: [Date]
Authorization: API {apiId}: [sign]
Body: [Body]
```

#### Example Header Fields
| Field | Description | Example |
|--------|-------------|----------|
| API URL | API endpoint | `https://www.soliscloud.com:13333/v1/api/inverterDetail` |
| Content-MD5 | MD5 hash of request body, base64 encoded | `kxdxk7rbAsrzSIWgEwhH4w==` |
| Date | GMT formatted time | `Fri, 26 Jul 2019 06:00:46 GMT` |
| Authorization | `API {apiId}:{sign}` | `API 1300386381676644416:ZkwJ4P01v4V1ihZLOXq0C7QCjXc=` |

#### Authorization Signature
```
Sign = base64(HmacSHA1(apiSecret,
  POST + "\n" + Content-MD5 + "\n" + Content-Type + "\n" + Date + "\n" + CanonicalizedResource))
```

### 2.3 Standard Return Format
```json
{
  "success": true,
  "code": "0",
  "msg": "success",
  "data": {}
}
```
- **`success`**: true for success, false for failure
- **`code`**: 0 = success, otherwise see Appendix 1
- **`msg`**: message text
- **`data`**: response payload

### 2.4 Example Call
```
POST /v1/api/userStationList
Content-MD5: kxdxk7rbAsrzSIWgEwhH4w==
Content-Type: application/json
Date: Fri, 26 Jul 2019 06:00:46 GMT
Authorization: API {apiId}:nBYQWeuzy3Y+gp67BN8zXTmvSDk=
Body: {"pageNo":1,"pageSize":10}
```

### 2.5 Encryption Tool Reference
- **MD5 Tool:** [https://dinochiesa.github.io/hmachash/index.html](https://dinochiesa.github.io/hmachash/index.html)
- **Java Auth Example:** [Authorization.java](https://ginlong-product.oss-cn-shanghai.aliyuncs.com/templet/Authorization.java)

---

## 3. Device Control Interfaces

### 3.1 Remote Control of a Single Inverter
- **URL:** `https://www.soliscloud.com:13333/v2/api/control`
- **Limit:** 2 req/sec

#### Request Body
| Field | Type | Required | Description |
|--------|------|-----------|-------------|
| inverterSn | String | Y | Inverter SN or ID (comma-separated for multiple) |
| inverterId | String | Y | Alternative to SN |
| cid | Long | Y | Command ID (see Appendix 2) |
| value | String | Y | Set value for command |
| nmiCode | String | N | For AU region |

#### Example
```json
{
  "inverterSn": "380205022C190102",
  "cid": 48,
  "value": 190
}
```

#### Response
```json
{
  "code": "0",
  "data": [
    {
      "msg": "380205022C190102 Time: 1688744454...",
      "code": 0,
      "recv": "01060BBE00BE6BBA",
      "command": "AT+TEST=GIN485:01 06 0b be 00 be 6b ba"
    }
  ],
  "time": "1688715605600"
}
```

---

### 3.2 Reading Parameter Values from Multiple Devices
- **URL:** `https://www.soliscloud.com:13333/v2/api/atRead`
- **Limit:** 2 req/sec

#### Request Body
| Field | Type | Required | Description |
|--------|------|-----------|-------------|
| inverterSn | String | Y | Device SN(s), comma-separated |
| nmiCode | String | N | AU region only |
| cid | Long | Y | Instruction ID (Appendix 2) |

#### Example Response
```json
{
  "msg": "success",
  "code": "0",
  "data": {
    "msg": "1",
    "yuanzhi": "-16143",
    "command": "AT+TEST=GIN485:01 03 a8 66 00 01 44 75",
    "needLoop": "false"
  },
  "orderId": "1688715608012_769",
  "time": "1688715608012"
}
```

---

### 3.3 Obtain Result Information by Order ID
- **URL:** `https://www.soliscloud.com:13333/v2/api/result`
- **Limit:** 2 req/sec

#### Request Body
| Field | Type | Required | Description |
|--------|------|-----------|-------------|
| orderId | String | Y | Identifier from previous request |

#### Example Response
```json
{
  "success": true,
  "code": "0",
  "msg": "success",
  "data": null
}
```

---

### 3.4 Read Parameter Values and Directly Return Results
- **URL:** `https://www.soliscloud.com:13333/v2/api/atReadSAPN`
- **Limit:** 2 req/sec

Supported dataloggers: `S1-W4G-ST`, `S2-WL-ST`, `S3-GPRS-ST`, `S3-WiFi ST`, `S4-WiFi ST`

#### Request Body
| Field | Type | Required | Description |
|--------|------|-----------|-------------|
| inverterSn | String | Y | Comma-separated SN list |
| nmiCode | String | Y | AU region device ID |
| cid | Long | Y | Command ID (Appendix 2) |

#### Example Response
```json
{
  "msg": "success",
  "code": "0",
  "data": [
    {
      "nmiCode": "20025543400",
      "code": "0",
      "sn": "380205022C190102",
      "value": "190",
      "cid": "48",
      "sendTime": "1688716346438"
    }
  ],
  "time": "1688716345767"
}
```

---

## Appendix 1: Return Status Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | Fail |
| Z0001 | Login expired |
| Z0002 | Content MD5 incorrect |
| 403 | No permissions |
| 429 | Too frequent requests |
| I0013 | Account/password error |
| B0020 | Verification code error |
| B0053 | Already bound to third-party account |
| R0004 | Feature restricted |
| B0107 | Collector model not supported |
| B0124 | Device SN does not exist |
| B0157 | Request time exceeded 5 min |
| R0000 | No permissions |

---

## Appendix 2: Instruction Comparison Table
[Download Command List (XLSX)](https://oss.soliscloud.com/doc/SolisCloud_control_api_command_list.xlsx)

