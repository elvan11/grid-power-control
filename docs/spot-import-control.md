# Spot-price import control

A schedule segment can select fixed controls or import at the cheapest times. Set the installation price area first. Spot controls keep their power cap throughout the window and allow grid charging only during the selected full quarters. 4.5 kWh at 6 kW requires three quarters.

The kWh target is nominal planned import capacity. House load, battery limits, inverter settings and command delays affect actual energy. Targets round up to full quarters. No telemetry feedback or catch-up purchases are performed.

Price integration uses ElprisLive get-prices server-side. All twelve Nordic areas are supported. UTC price intervals are matched against installation-local schedules, including daylight-saving changes. Missing prices keep charging off and retry every five minutes. Once an occurrence starts, its chosen quarters stay fixed except explicit configuration edits; elapsed allocations are retained across edits.

Deployment order: migration and executor, smoke tests, web release, minute cron. Existing gateway JWT verification must remain disabled. Before relying on this mode, observe the inverter during one selected and one unselected quarter; confirm CID 5035 preserves the cap and CID 5041 permits/stops charging. This cannot be proved from command readback alone.

Time-zone changes must be made outside active spot-import windows (checked in both old and new time zones) to preserve the current budget.
