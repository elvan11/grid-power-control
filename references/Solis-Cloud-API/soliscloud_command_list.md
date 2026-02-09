| cid | Control Option Name | Value | Unit |
|-----:|----------------------|--------|------|
| 13 | Grid Code | | |
| 14 | Limited Reactive Power Value | | % |
| 15 | Power Limit Value | | % |
| 18 | Inverter Time Setting | yyyy-MM-dd HH:mm:ss | |
| 19 | 10min Voltage Set | | V |
| 20 | OV-G-V 01 | | V |
| 21 | UN-G-V 01 | | V |
| 24 | Total Yield Calibration | | kWh |
| 25 | This Month Yield Calibration | | kWh |
| 26 | Last Month Yield Calibration | | kWh |
| 27 | Today Yield Calibration | | kWh |
| 28 | Yesterday Yield Calibration | | kWh |
| 29 | This Year Yield Calibration | | kWh |
| 30 | Last Year Yield Calibration | | kWh |
| 44 | OV-G-F 01 | | Hz |
| 45 | UN-G-F 01 | | Hz |
| 48 | On | 190 | |
| 52 | ON | 190 | |
| 53 | Off | 222 | |
| 54 | OFF | 222 | |
| 56 | Inverter Time Setting | yyyy-MM-dd HH:mm:ss | |
| 100 | Time of Use Select | `[{"name": "Not enabled", "value": "0"},{"name": "Enabled", "value": "1"}]` | refer to 636 |
| 103 | Charge and discharge Settings | Complex JSON with charge/discharge currents, times, SOC, voltage settings for 3 time slots (see documentation) | A, hh:mm, % |
| 155 | Battery Model | `[{"name": "None", "value": "0"},{"name": "PYLON_HV BYD High Voltage Battery", "value": "256"},{"name": "User define", "value": "512"},{"name": "B_BOX_HV BYD High Voltage Battery", "value": "768"},{"name": "LG_HVLG High Voltage Battery", "value": "1024"},{"name": "SOLUNA_HV Delaunen High Voltage Battery", "value": "1280"},{"name": "Dyness HV Daqin High Voltage Battery", "value": "1536"},{"name": "Aoboet HV Aoboet High Voltage Battery", "value": "1792"},{"name": "WECO HV", "value": "2048"},{"name": "Alpha HV Voltaic High Voltage Battery", "value": "2304"}]` | (Multiple models) |
| 156 | Battery Model | Complex JSON with High Voltage and Low Voltage battery options | (Multiple models) |
| 157 | Reserved SOC | | % |
| 158 | Overdischarge SOC | | % |
| 160 | Forcecharge SOC | | % |
| 162 | Max Charging Current | | A |
| 163 | Max Discharging Current | | A |
| 166 | Battery Overvoltage Protection Setting | | V |
| 167 | Battery Undervoltage Protection Setting | | V |
| 168 | Battery Wakeup | `[{"name": "Off", "value": "0"},{"name": "On", "value": "1"}]` | |
| 171 | Failsafe Select | `[{"name": "Off", "value": "0"},{"name": "On", "value": "1"}]` | |
| 172 | Battery Capacity | | |
| 173 | Power Factor Setting Value | | |
| 178 | AFCI Protect | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 180 | LSB | | |
| 181 | HSB | | |
| 182 | LDB | | |
| 183 | HDB | | |
| 184 | Pcharge | | |
| 185 | Pdischarge | | |
| 186 | FCAS Droop Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 188 | Passive Mode | `[{"name":"OFF","value":"0"},{"name":"ON","value":"43605"}]` | |
| 225 | EPS Switching Time | | |
| 226 | EPS DOD | | |
| 234 | Power Limit Switch | `[{"name":"OFF","value":"85"},{"name":"ON","value":"170"},{"name":"Disable","value":"0"}]` | |
| 235 | | `[{"name":"OFF","value":"85"},{"name":"ON","value":"161"}]` | |
| 236 | | `[{"name":"OFF","value":"85"},{"name":"ON","value":"162"}]` | |
| 262 | Recover-VH | | V |
| 263 | Recover-VL | | V |
| 264 | Recover-FH | | Hz |
| 265 | Recover-FL | | Hz |
| 267 | Startup-VH | | V |
| 268 | Startup-VL | | V |
| 269 | Startup-FH | | Hz |
| 270 | Startup-FL | | Hz |
| 277 | Power rise control slope | | % |
| 278 | Power drop control slope | | % |
| 284 | Work Mode | `[{"name": "Self-Powered", "value": "0"},{"name": "Battery Retention", "value": "1"},{"name": "Standby Mode", "value": "2"}]` | |
| 285 | Charging Source Setting | `[{"name": "PV Only", "value": "0"},{"name": "PV&GRID", "value": "1"}]` | |
| 286 | Buzzer Alarm Enable | `[{"name": "Not enabled", "value": "0"},{"name": "Enabled", "value": "1"}]` | |
| 287 | Battery Model | `[{"name": "None", "value": "0"},{"name": "PYLON_LV Dispatch Low Voltage Battery", "value": "1"},{"name": "User define", "value": "2"},{"name": "B_BOX_LVBYD Low Voltage Battery", "value": "3"},{"name": "Dyness LV", "value": "4"},{"name": "Lead Acid", "value": "100"}]` | |
| 289 | Battery Low Voltage | | V |
| 290 | Battery High Voltage | | V |
| 291 | Battery Over Voltage Value | | V |
| 292 | Battery Under Voltage Value | | V |
| 293 | Force Limit Power | | A |
| 294 | Force Voltage | | V |
| 295 | Forcecharge SOC | 10 | % |
| 296 | Battery Max SOC | | % |
| 297 | Overdischarge SOC | | % |
| 303 | Lead Acid TEMP CO | | mV/℃ |
| 305 | Battery Capacity | | Ah |
| 307 | Backup Port Enabling Setting | `[{"name": "Do not enable", "value": "0"},{"name": "Enable", "value": "1"}]` | |
| 308 | Backup Port Reference Voltage Setting | | V |
| 309 | Clear Yield Data | `[{"name": "Do not clear", "value": "0"},{"name": "Clear generation", "value": "1"}]` | |
| 310 | Factory Reset | `[{"name": "Off", "value": "0"},{"name": "Restore factory settings", "value": "1"}]` | |
| 311 | Quick Charge Enable | `[{"name": "Do not enable", "value": "0"},{"name": "Charge", "value": "1"}]` | |
| 312 | Quick Charge | `[{"name": "No Execution", "value": "0"},{"name": "Execution", "value": "43605"}]` | |
| 316 | Batt Line ZO | | mΩ |
| 317 | AC Input Type | `[{"name": "Grid", "value": "0"},{"name": "Generator", "value": "1"},{"name": "Generator-ATS", "value": "2"}]` | |
| 318 | On Grid Pv Gen | `[{"name": "Not Enabled", "value": "0"},{"name": "Enabled", "value": "1"}]` | |
| 319 | On Grid Pv Gen | `[{"name": "Not enabled", "value": "0"},{"name": "Enabled", "value": "1"}]` | |
| 321 | Equalizing Enable | `[{"name": "Not enabled", "value": "0"},{"name": "Enabled", "value": "1"}]` | |
| 323 | Equalizing Active Immdly | `[{"name": "Not Enabled", "value": "0"},{"name": "Enabled", "value": "1"}]` | |
| 324 | Equalizing Voltage | | V |
| 325 | Equalizing Time | | min |
| 326 | Equalizing Timeout | | min |
| 327 | Equalizing Interval | | day |
| 313 | Constant Voltage Mode | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 314 | Constant Voltage Mode Setting Voltage Value | | |
| 331 | | `[{"name": "Mode 1", "value": "1"},{"name": "Mode 2", "value": "2"},{"name": "Mode 3", "value": "3"}]` | |
| 334 | Delay Time Setting for Indicator Off | | S |
| 335 | Fault Alarm Indicator Enable | `[{"name": "Not enabled", "value": "2"},{"name": "Enabled", "value": "1"}]` | |
| 336 | Fault Alarm Duration Setting | | Min |
| 342 | Voltage Droop Setting | `[{"name": "Not enabled", "value": "0"},{"name": "Enabled", "value": "1"}]` | |
| 343 | Power Calibration Factor | | |
| 345 | MPPT Parallel Mode | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 346 | IgFollow | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 347 | Relay-Fault Func | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 348 | ILeak-Fault Func | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 349 | PV-G-Fault Func | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 350 | GRID-INTF.02 Func | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 351 | IgADCheckPRO | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 352 | Grid Filter No | | |
| 354 | LVRT_02 | `[{"name":"Resistive","value":"1"},{"name":"Capacitive","value":"0"}]` | |
| 355 | VRT_US | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 356 | FRT_US | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 357 | LVRT_BRA | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 360 | Igrid-B-Zero | | |
| 361 | Igrid-C-Zero | | |
| 362 | VFB-AdJ-Scale | | |
| 363 | ILeakLim | | |
| 364 | RisoLim | | |
| 367 | Meter Setting | `[{"name":"Grid-side Acrel1P","value":"257"},{"name":"Grid-sideAcrel3P","value":"258"},{"name":"Grid-side Acrel3P","value":"259"},{"name":"Grid-sideEastron1P","value":"260"},{"name":"Grid-sideEastron3P","value":"261"},{"name":"Grid-sideNo MeterMode","value":"262"},{"name":"Load-side Acrel1P","value":"513"},{"name":"Load-sideAcrel3P","value":"514"},{"name":"Load-side Acrel3P","value":"515"},{"name":"Load-sideEastron1P","value":"516"},{"name":"Load-sideEastron3P","value":"517"},{"name":"Load-sideNo MeterMode","value":"518"},{"name": "Grid-side+Shunt Inverter Output Side (Dual Meter) Universal 1P only for Eastron meters", "value": "769"},{"name": "Grid-side+Shunt Inverter Output Side (Dual Meter) Acrel3P only for Eastron meters", "value": "770"},{"name": "Grid-side+Shunt Inverter Output Side (Dual Meter) Universal 3P only for Eastron meters", "value": "771"},{"name": "Grid-side+Shunt Inverter Output Side (Dual Meter) Eastron1P only for Eastron meters", "value": "772"},{"name": "Grid-side+Shunt Inverter Output Side (Dual Meter) Eastron3P only for Donghorn meters", "value": "773"},{"name": "Grid-side+Shunt Inverter Output Side (Dual Meter) No MeterMode only for Donghorn meters", "value": "774" }]` | |
| 375 | Limited Reactive Power Value | | % |
| 376 | Inverter Max Output Power Setting | | % |
| 378 | Grid Code Work Mode | `[{"name":"No response mode","value":"0"},{"name":"P Mode-Volt-vatt","value":"1"},{"name":"Q Mode-Volt-var","value":"2"},{"name":"Fix PF","value":"3"},{"name":"Fix Reactive","value":"4"},{"name":"P-Factor","value":"5"},{"name":"Power-Q","value":"6"}]` | |
| 379 | PbSet-05mode | | % |
| 380 | PcSet-05mode | | % |
| 381 | VRT Switch | `[{"name":"Enable","value":"90"},{"name":"Disable","value":"165"}]` | |
| 383 | PFcSet-05mode | | |
| 384 | Limited Reactive Power Value-04mode | | % |
| 385 | Power Factor Setting Value-03mode | | |
| 386 | V1Set-02mode | | V |
| 387 | V2Set-02mode | | V |
| 388 | V3Set-02mode | | V |
| 389 | V4Set-02mode | | V |
| 390 | Max Leading Limit | | % |
| 391 | Max Lagging Limit | | % |
| 392 | K Coeff-02mode | | |
| 393 | Plock-in-02mode | | % |
| 394 | Plock-out-02mode | | % |
| 395 | V1Set-01mode | | V |
| 396 | P1Set-01mode | | % |
| 397 | V2Set-01mode | | V |
| 398 | P2Set-01mode | | % |
| 399 | V3Set-01mode | | V |
| 400 | P3Set-01mode | | % |
| 401 | V4Set-01mode | | V |
| 402 | P4Set-01mode | | % |
| 403 | Gradient Limit for Power Change | | % |
| 404 | EN50549 Gradient Limit for Power-on Change | | % |
| 405 | EN50549 Power Change Gradient after Fault Trip Restart | | % |
| 406 | Frequency Derating Mode | `[{"name": "00-No requirement", "value": "0"},{"name": "01-Australia", "value": "1"},{"name": "03-VDE&EN50438", "value": "3"},{"name": "04-USRule21", "value": "4"},{"name": "05-Brazil", "value": "5"},{"name": "06-South Africa", "value": "6"},{"name": "07-US Rule21Phase1", "value": "7"},{"name": "08-US Rule21Phase3", "value": "8"},{"name": "09-Dubai", "value": "9"},{"name": "0A-UK G98&G99", "value": "10"},{"name": "0B-Germany BDEW", "value": "11"},{"name": "0C-Denmark", "value": "12"},{"name": "0D-China 2018 New Standard", "value": "13"},{"name": "0E-EN50549", "value": "14"},{"name": "0F-CEI 0-21", "value": "15"},{"name": "10H-South Africalevelise", "value": "16"},{"name": "11H-France", "value": "17"},{"name": "12H-Austria", "value": "18"},{"name": "13H-Hawaii", "value": "19"}]` | |
| 407 | 01-Frequency Derating Fstop | | Hz |
| 408 | 0C-Frequency Derating Fstart | | Hz |
| 409 | 0A-Frequency Derating Fstart | | |
| 410 | 03&11H&12H-Frequency Derating Fstart | | Hz |
| 411 | 13H-Frequency Derating Fstart | | Hz |
| 412 | 04-Frequency Derating Fstart | | Hz |
| 413 | 08-Frequency Derating Fstart | | Hz |
| 414 | 0D-Frequency Derating Slope(Fdroop) | | % |
| 415 | 0E-Frequency Derating F1 | | Hz |
| 416 | 01-Under-Freq Derate Fstart | | Hz |
| 417 | 0C&0A-Frequency Derating Slope(Fdroop) | | % |
| 418 | 03&11H&12H-Frequency Derating Slope(Fdroop) | | % |
| 419 | 13H-Frequency Derating Slope(Fdroop) | | % |
| 420 | 04-Frequency Derating Fstop | | Hz |
| 421 | 08-Frequency Derating Slope(Wgra) | | % |
| 423 | 0E-Frequency Derating Hysteresis | `[{"name": "Not enabled", "value": "0"},{"name": "Enabled", "value": "1"}]` | |
| 424 | 01-Frequency Derating Fstart | | |
| 425 | 08-Frequency Derating Fstop | | Hz |
| 426 | 0E-Frequency Derating Fstop | | Hz |
| 427 | 13H-Frequency Derating Response Time | | ms |
| 428 | 01-Frequency Derating Ftransition | | |
| 429 | 08-Frequency Derating Hysteresis Enable Select (HystEna) | `[{"name": "Not Enabled", "value": "0"},{"name": "Enabled", "value": "1"}]` | |
| 430 | 0E-Frequency Derating hysteresis response time (Tstop) | | s |
| 431 | 0E-Frequency Derating Slope(Fdroop) | | % |
| 432 | 0E-Frequency Derating Response Delay (Tintendelay) | | s |
| 433 | 01-Underfrequency Ramping Fdstart | | |
| 434 | 03&0E-Underfrequency Ramping Fdstart | | Hz |
| 435 | 13H-Underfrequency Ramping Fdstart | | Hz |
| 436 | 01-Underfrequency Ramping Fpmax | | |
| 437 | 03&0E-Underfrequency Ramping FD_Droop | | % |
| 438 | 13H-Underfrequency Ramping FD_Droop | | % |
| 439 | 01-Power derate change slope limit (Wgra-) | | |
| 440 | 3Tau(Q)Setting | | S |
| 441 | 10min Overvoltage Setting | | V |
| 442 | OverVolt Auto PLmt | `[{"name": "Not Enabled", "value": "0"},{"name": "Enabled", "value": "1"}]` | |
| 443 | DRM Switch | `[{"name": "DRM On", "value": "1"},{"name": "DRM Off", "value": "2"}]` | |
| 444 | Remote active power percentage limit (Power control) | | |
| 446 | V1 Set | | V |
| 447 | P1% Set | | % |
| 448 | V2 Set | | V |
| 449 | P2% Set | | % |
| 450 | V3 Set | | V |
| 451 | P3% Set | | % |
| 452 | V4 Set | | V |
| 453 | P4% Set | | % |
| 462 | Inverter Max Output Power Setting With Restore | `[{"name": "Off", "value": "0"},{"name": "On", "value": "1"}]` | |
| 463 | Power Down Saving Function | `[{"name":"OFF","value":"0"},{"name":"ON","value":"15"}]` | |
| 466 | Self-Use Mode Select | `[{"name": "Not enabled", "value": "0"},{"name": "Enabled", "value": "1"}]` | refer to 636 |
| 469 | Off-Grid Overdischarge SOC | | % |
| 471 | Grid Code | | |
| 472 | OV-G-V 01 | | V |
| 473 | OV-G-V-T 01 | | S |
| 474 | OV-G-V 02 | | V |
| 475 | OV-G-V-T 02 | | S |
| 476 | UN-G-V 01 | | V |
| 477 | UN-G-V-T 01 | | S |
| 478 | UN-G-V 02 | | V |
| 479 | UN-G-V-T 02 | | S |
| 480 | OV-G-F 01 | | Hz |
| 481 | OV-G-F-T 01 | | S |
| 482 | OV-G-F 02 | | Hz |
| 483 | OV-G-F-T 02 | | S |
| 484 | UN-G-F 01 | | Hz |
| 485 | UN-G-F-T 01 | | S |
| 486 | UN-G-F 02 | | Hz |
| 487 | UN-G-F-T 02 | | S |
| 488 | Startup-VH | | V |
| 489 | Startup-VL | | V |
| 490 | Recover-VH | | V |
| 491 | Recover-VL | | V |
| 492 | Startup-FH | | Hz |
| 493 | Startup-FL | | Hz |
| 494 | Recover-FH | | Hz |
| 495 | Recover-FL | | Hz |
| 496 | Startup-T | | S |
| 497 | Restore-T | | S |
| 499 | System Export Power Limit Value | | W |
| 500 | Inverter Max Output Power Setting(AS4777-A\B\C\N) | | % |
| 502 | Power Factor Setting Power Down Storage | `[{"name":"关","value":"0"},{"name":"开","value":"1"}]` | |
| 505 | | | |
| 506 | | | |
| 507 | Initial Setting | `[{"name": "Standard operating mode restore default", "value": "3"},{"name": "Power change slope restore default", "value": "4"},{"name": "Frequency load shedding restore default", "value": "5"},{"name": "Sliding window protection restore default", "value": "6"}]` | |
| 515 | No boost | `[{"name":"on","value":"0"},{"name":"off","value":"1"}]` | |
| 516 | DC inject Adj | `[{"name":"on","value":"0"},{"name":"off","value":"1"}]` | |
| 517 | Set Slave Address | | |
| 532 | Work Mode | `[{"name":"No response mode","value":"0"},{"name":"Volt-watt default","value":"1"},{"name":"Volt-var","value":"2"},{"name":"Fixed power factor","value":"3"},{"name":"Fix reactive power","value":"4"},{"name":"Power-PF","value":"5"}]` | |
| 534 | Power Factor Setting Value 02 | 0.8-1 | |
| 535 | Power Factor Setting Value | -1 - -0.8 | |
| 536 | Limit Power Value | | |
| 537 | Reactive Power Limit Switch | | |
| 538 | Max Grid Charging Current | | A |
| 539 | Bypass Power Supply Reference Frequency Setting | `[{"name": "50Hz", "value": "50"},{"name": "60Hz", "value": "60"}]` | Hz |
| 540 | Constant Voltage Mode | `[{"name": "Not enabled", "value": "0"},{"name": "Enabled", "value": "1"}]` | |
| 541 | Constant Voltage Mode Setting Voltage Value | | V |
| 542 | AFCI level | `[{"name": "0", "value": "0"}, {"name": "1", "value": "1"}, {"name": "2", "value": "2"}, {"name": "3", "value": "3"}, {"name": "4", "value": "4"}, {"name": "5", "value": "5"}, {"name": "6", "value": "6"}, {"name": "7", "value": "7"}]` | |
| 544 | Battery Wakeup | `[{"name": "Off", "value": "0"},{"name": "On", "value": "1"}]` | |
| 548 | | | |
| 549 | | `[{"name":"Voltage 0.1V, Time 0.01s, Frequency 0.01Hz","value":"0"},{"name":"Voltage 1V, Time 0.1s, Frequency 0.1Hz","value":"1"},{"name":"Voltage 0.1V, Time 0.02s, Frequency 0.01Hz","value":"256"}]` | |
| 555 | 10min Voltage Set | | V |
| 556 | OV-G-V 01 | | V |
| 557 | UN-G-V 01 | | V |
| 560 | OV-G-F 01 | | Hz |
| 561 | UN-G-F 01 | | Hz |
| 567 | OV-G-V 02 | | V |
| 568 | UN-G-V 02 | | V |
| 569 | OV-G-F 02 | | Hz |
| 570 | UN-G-F 02 | | Hz |
| 571 | SVG Reactive Power | | % |
| 572 | External Anti-PID | `[{"name":"OFF","value":"85"},{"name":"ON","value":"170"}]` | |
| 574 | Parallel Physical Address ID | | |
| 575 | Master Create Method | `[{"name": "Auto Competition", "value": "0"},{"name": "Manual Setting", "value": "1"}]` | |
| 576 | Manual Set Master/Slave | `[{"name": "Slave", "value": "0"},{"name": "Master", "value": "1"}]` | |
| 577 | Critical Load capacity connected on this phase (where this inverter is on) | | kVA |
| 578 | Inverter Connected Phase Setting | `[{"name": "Not set", "value": "0"},{"name": "Single-phase system", "value": "1"},{"name": "A-phase of three-phase system", "value": "2"},{"name": "B-phase of three-phase system", "value": "3"},{"name": "C-phase of three-phase C phase of a three-phase system", "value": "4"}]` | |
| 579 | Battery Connected Mode Setting | `[{"name": "Battery parallel, off-grid battery equalisation according to inverter rated power", "value": "0"},{"name": "Battery independent, off-grid battery equalisation according to actual battery capacity", "value": "1"}]` | |
| 580 | Request Synchronisation | `[{"name": "No sync required", "value": "0"},{"name": "Sync required", "value": "1"}]` | |
| 594 | Grid standard protection parameter accuracy | `[{"name": "Voltage 0.1V, Time 0.01s, Frequency 0.01Hz", "value": "0"},{"name": "Voltage 1V, Time 0.1s, Frequency 0.1Hz", "value": "1"}]` | |
| 601 | | | |
| 602 | | | |
| 603 | Limit Reactive Power Value | | % |
| 604 | Pb% Set | | % |
| 605 | Pc% Set | | % |
| 606 | PFc Set | | |
| 607 | 27.S1 | | |
| 609 | 27.S2 | | |
| 611 | 59.S1 | | |
| 613 | 59.S2 | | |
| 632 | System Export Current Limit Value | | A |
| 634 | Meter CT Wiring Direction Setting | `[{"name": "Forward", "value": "0"},{"name": "Reverse", "value": "1"}]` | |
| 636 | Storage Inverters Control Switching | Bit-based control (see documentation for BIT definitions) | Decimal |
| 648 | | `[{"name":"OFF","value":"85"},{"name":"ON","value":"170"}]` | |
| 650 | | | |
| 651 | Internal EPM Setting | | |
| 675 | Forcecharge Power Source Setting | | |
| 676 | Max. grid power when Force charging | | W |
| 682 | Overdischarge Voltage | | |
| 683 | Force Voltage | | V |
| 684 | | | V |
| 686 | | | V |
| 687 | Temperature compensation coefficient | | |
| 696 | Feed in Power Limit Value | | |
| 706 | Phase A Rated Power Limit | | |
| 707 | Phase B Rated Power Limit | | |
| 708 | C相额定功率限制值 | | |
| 713 | Battery Psmax percentage setting (only for CEI 0-21) | | |
| 714 | Battery Pcmax percentage setting (only for CEI 0-21) | | |
| 737 | Igrid-A-Zero | | |
| 801 | Phase A Voltage Compensation | | |
| 802 | Phase B Voltage Compensation | | |
| 803 | Phase C Voltage Compensation | | |
| 809 | 3Tau(P)Setting | | |
| 810 | Vref-Autonomous | | |
| 4611 | Meter/CT Setting | `[{"name":"CT","value":"1"},{"name":"Meter","value":"0"}]` | |
| 4612 | CT Ratio | | |
| 4615 | Feed in Power Limit Swtich | `[{"name": "Off", "value": "0"},{"name": "On", "value": "1"}]` | |
| 4618 | Feed in Current Limit Value | | |
| 4619 | GEN Force | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 4623 | With Generator | `[{"name":"YES","value":"1"},{"name":"NO","value":"0"}]` | |
| 4624 | GEN Rated Power | | |
| 4625 | Gen Max. Charge Power | | |
| 4626 | Generator Position | `[{"name":"Grid","value":"1"},{"name":"Generator","value":"0"}]` | |
| 4627 | Grid Port Powered By | `[{"name":"Generator","value":"1"},{"name":"Grid","value":"0"}]` | |
| 4628 | GEN signal | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 4630 | GEN Stop | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 4632 | Peak-shaving Setting | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 4633 | ECO Function | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 4666 | GEN_Start_SOC | | |
| 4667 | GEN_Exit_SOC | | |
| 4742 | Battery Wakeup Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 4743 | Battery WakeupVoltage Setting | | |
| 4744 | Battery WakeupTime Setting | | |
| 4747 | Feed in Current Limit Swtich | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 4748 | Internal EPM Hard Limit Switch | `[{"name":"OFF","value":"2"},{"name":"ON","value":"1"}]` | |
| 4749 | Power Hard Limit Value | | |
| 4751 | Min.Droop Voltage | | |
| 4754 | MPPT Multi-peak Scanning Switch | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 4755 | MPPT Multi-peak Scan Interval | | |
| 4756 | Daily PV-ISO Detection | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 4758 | GEN_Start_Volt | | |
| 4759 | GEN_Exit_Volt | | |
| 4760 | GEN Port Load ON | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 4762 | AC Coupling Switch | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 4763 | Position | `[{"name":"GEN port","value":"0"},{"name":"Backup port","value":"1"}]` | |
| 4764 | AC Coupling_OFF_SOC | | |
| 4765 | AC Coupling_OFF_Volt | | |
| 4766 | AC Coulpling Max.fre | | |
| 4767 | Physical Address ID | | |
| 4768 | Parallel Mode | `[{"name":"Single","value":"0"},{"name":"Parallel","value":"1"}]` | |
| 4770 | Manual Set Master/Slave | `[{"name":"Slave","value":"0"},{"name":"Master","value":"1"}]` | |
| 4771 | Inverter Connected Phase Setting | `[{"name":"None","value":"0"},{"name":"Single Phase","value":"1"},{"name":"Phase A(Three Phase)","value":"2"},{"name":"Phase B(Three Phase)","value":"3"},{"name":"Phase C(Three Phase)","value":"4"}]` | |
| 4772 | Battery Rated Energy Setting | | |
| 4773 | Total number of hybrid inverters connected | | |
| 4774 | Parallel Sync | | |
| 4778 | AFCI Test Switch | `[{"name":"PV1","value":""},{"name":"PV2","value":""},{"name":"PV3","value":""},{"name":"PV4","value":""},{"name":"PV5","value":""},{"name":"PV6","value":""},{"name":"PV7","value":""},{"name":"PV8","value":""},{"name":"PV9","value":""},{"name":"PV10","value":""}]` | |
| 4779 | AFCI Test | | |
| 4845 | LG Parallel Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 4847 | Battery Healing Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 4848 | Battery Healing SOC | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 4869 | SPH Switch | `[{"name":"DisConnect","value":"0"},{"name":"Connect","value":"1"}]` | |
| 4872 | Load 1 Switch | `[{"name":"Disable","value":"0"},{"name":"Enable","value":"1"}]` | |
| 4873 | Load 2 Switch | `[{"name":"Disable","value":"0"},{"name":"Enable","value":"1"}]` | |
| 4874 | Load 3 Switch | `[{"name":"Disable","value":"0"},{"name":"Enable","value":"1"}]` | |
| 4875 | Load 4 Switch | `[{"name":"Disable","value":"0"},{"name":"Enable","value":"1"}]` | |
| 4880 | Smart Load Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 4881 | Min.Feed in Power | | |
| 4882 | Load_ON_Batt SOC | | |
| 4883 | Load_OFF_Batt SOC | | |
| 4884 | Load_ON_Batt Volt | | |
| 4885 | Load_OFF_Batt Volt | | |
| 4921 | Unblance Output | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 4938 | Backup Reference Frequency Setting | | |
| 5035 | Peak-shaving mode: Max.usable Grid Power | | W |
| 5037 | Peak-shaving mode: Baseline SOC | | % |
| 5064 | G100 Switch | `[{"name":"Enable","value":"1"},{"name":"Disable","value":"0"}]` | |
| 5065 | G100 Backflow Current | | |
| 5916 | Charge Time Slot 1 Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | New optimized earnings parameters |
| 5917 | Charge Time Slot 2 Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 5918 | Charge Time Slot 3 Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 5919 | Charge Time Slot 4 Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 5920 | Charge Time Slot 5 Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 5921 | Charge Time Slot 6 Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 5922 | Discharge Time Slot 1 Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 5923 | Discharge Time Slot 2 Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 5924 | Discharge Time Slot 3 Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 5925 | Discharge Time Slot 4 Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 5926 | Discharge Time Slot 5 Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 5927 | Discharge Time Slot 6 Switch | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
| 5928 | SOC1 | | |
| 5929 | SOC2 | | |
| 5930 | SOC3 | | |
| 5931 | SOC4 | | |
| 5932 | SOC5 | | |
| 5933 | SOC6 | | |
| 5946 | Charge Time Slot 1 | | |
| 5947 | Volt 1 | | |
| 5948 | Charge Current 1 | | |
| 5949 | Charge Time Slot 2 | | |
| 5950 | Volt 2 | | |
| 5951 | Charge Current 2 | | |
| 5952 | Charge Time Slot 3 | | |
| 5953 | Volt 3 | | |
| 5954 | Charge Current 3 | | |
| 5955 | Charge Time Slot 4 | | |
| 5956 | Volt 4 | | |
| 5957 | Charge Current 4 | | |
| 5958 | Charge Time Slot 5 | | |
| 5959 | Volt 5 | | |
| 5960 | Charge Current 5 | | |
| 5961 | Charge Time Slot 6 | | |
| 5962 | Volt 6 | | |
| 5963 | Charge Current 6 | | |
| 5964 | Discharge Time Slot 1 | | |
| 5965 | SOC1 | | |
| 5966 | Volt 1 | | |
| 5967 | Discharge Current 1 | | |
| 5968 | Discharge Time Slot 2 | | |
| 5969 | SOC2 | | |
| 5970 | Volt 2 | | |
| 5971 | Discharge Current 2 | | |
| 5972 | Discharge Time Slot 3 | | |
| 5973 | SOC3 | | |
| 5974 | Volt 3 | | |
| 5975 | Discharge Current 3 | | |
| 5976 | Discharge Time Slot 4 | | |
| 5977 | SOC4 | | |
| 5978 | Volt 4 | | |
| 5979 | Discharge Current 4 | | |
| 5980 | Discharge Time Slot 5 | | |
| 5981 | SOC5 | | |
| 5982 | Volt 5 | | |
| 5983 | Discharge Current 5 | | |
| 5984 | SOC6 | | |
| 5985 | Volt 6 | | |
| 5986 | Discharge Current 6 | | |
| 5987 | Discharge Time Slot 6 | | |
| 6972 | Charge and Discharge Settings via one CID | Complex combined charge/discharge settings with time slots, currents, SOC, voltage (see documentation) | `/v2/api/control For example: {"cid":"6972","inverterSn":"XXXXXXXX",,value:"1,00:00-02:00,100,22,25,1,02:00-04:00,100,22,25,1,06:00-08:00,100,22,25,1,08:00-10:00,100,22,25,1,10:00-12:00,100,22,25,1,08:00-10:00,100,22,25,1,10:00-12:00,100,22,25,1,12:00-14:00,100,22,25,1,14:00-16:00,100,22,25,1,16:00-18:00,100,22,25,1,18:00-20:00,100,22,25,1,20:00-22:00,100,22,25,1,22:00-00:00,100,22,25",yuanzhi:"0,19:00-20:00,105,12,15,0,19:00-20:00,105,12,15,0,19:00-20:00,105,12,15,0,19:00-20:00,105,12,15,0,19:00-20:00,105,12,15,0,19:00-20:00,105,12,15,0,19:00-20:00,105,12,15,0,19:00-20:00,105,12,15,0,19:00-20:00,105,12,15,0,19:00-20:00,105,12,15,0,19:00-20:00,105,12,15,0,19:00-20:00,105,12,15",localTimeZone:8,"language":"1"} Both "value" and "yuanzhi" consist of 5 parameters per group, representing the following in order: the on/off switch for charge/discharge period, the charge/discharge time slot, the current, the SOC, and the voltage.  Up to 12 sets can be configured (6 charge + 6 discharge), corresponding to charge periods 1 through 6 and discharge periods 1 through 6 in sequence.` |
| 43110 | Allow Grid Charging | `[{"name":"OFF","value":"0"},{"name":"ON","value":"1"}]` | |
