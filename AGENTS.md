# AGENTS.md

This base needs in the project is documented in [base-needs.md](base-needs.md).

## Project Overview

A mobile app for scheduled control of solar + battery installations. Users create weekly control schedules to manage peak shaving (adjustable power limits) and grid charging settings across different time segments and days of the week. The app supports multiple daily schedules that can be assigned to specific days or day ranges, with real-time display of active controls and manual override capabilities.

## Tools and Technologies

- **Stitch**: Used for UI layout design. Project ID: 14483047077387457262
- **SolisCloud API**: Integration with Solis inverter cloud API for remote control of solar + battery systems

## SolisCloud API Integration

### Key Control Parameters (CID)
- **CID 43110**: Grid power limit setting for peak shaving
- **CID 5035**: Alternative/backup power limit control parameter

### API Reference Implementation
Python reference scripts demonstrating API usage patterns:
- [poll_solis_atread.py](references/poll_solis_atread.py) - Reading parameter values from SolisCloud
- [apply_schedule_slot.py](references/apply_schedule_slot.py) - Applying schedule-based control commands to inverter

Refer to [soliscloud_command_list.md](references/Solis-Cloud-API/soliscloud_command_list.md) for complete CID command reference.