"""Apply current 15-minute schedule slot to Solis peak shaving power limit.

Reads expanded schedule from www/peak_schedule_today.json (written by peak_schedule.expand_today).
Determines current slot index, desired cap kW, and SOC floor.
If battery SOC below floor -> reduce requested cap (soft fallback).
Compares with current CID 5035 watts (input_text.solis_cid_5035_raw) and applies change if delta >= threshold.
Respects dry-run boolean (input_boolean.schedule_dry_run) to log intent only.
"""
import json
from datetime import datetime
import time

PATH = hass.config.path('www/peak_schedule_today.json')
THRESHOLD_W = 50  # minimum difference before applying
FALLBACK_LOW_SOC_KW = 0.3  # reduced cap when SOC below floor

now = datetime.now()
minute_index = (now.hour * 60 + now.minute) // 15

# Load schedule file
try:
    with open(PATH, 'r', encoding='utf-8') as f:
        doc = json.load(f)
except FileNotFoundError:
    logger.warning('Schedule runner: file missing %s', PATH)
    return
except Exception as err:  # noqa: BLE001
    logger.warning('Schedule runner: failed reading %s: %s', PATH, err)
    return

slots = doc.get('slots') or []
if not isinstance(slots, list) or len(slots) < minute_index + 1:
    logger.warning('Schedule runner: invalid slots for day=%s', doc.get('day'))
    return

slot = slots[minute_index]
target_cap_kw = float(slot.get('target_cap_kw', 0.0))
soc_floor_pct = int(slot.get('soc_floor_pct', 15))

# Gather current state values
battery_soc = hass.states.get('sensor.battery_soc')
soc_val = float(battery_soc.state) if battery_soc and battery_soc.state not in ['unknown','unavailable','none'] else 0.0

# Read current limit from template sensor (abstracts input_text helper)
limit_sensor = hass.states.get('sensor.solis_peak_shaving_power_limit')
current_limit_w = float(limit_sensor.state) if limit_sensor and limit_sensor.state not in ['unknown','unavailable','none'] else 0.0

dry_run_entity = hass.states.get('input_boolean.schedule_dry_run')
dry_run = dry_run_entity.state == 'on' if dry_run_entity else False

# SOC enforcement: if SOC below floor, reduce cap but keep non-negative
if soc_val < soc_floor_pct:
    # Choose smaller of existing target and fallback kw
    target_cap_kw = min(target_cap_kw, FALLBACK_LOW_SOC_KW)

requested_w = int(round(target_cap_kw * 1000))
delta = requested_w - int(round(current_limit_w))

event_base = {
    'slot_index': minute_index,
    'timestamp': datetime.utcnow().isoformat() + 'Z',
    'current_limit_w': int(round(current_limit_w)),
    'requested_limit_w': requested_w,
    'delta_w': delta,
    'soc_pct': soc_val,
    'soc_floor_pct': soc_floor_pct,
    'dry_run': dry_run,
}

if abs(delta) < THRESHOLD_W:
    event = dict(event_base)
    event['event'] = 'slot_skip_threshold'
    event['threshold_w'] = THRESHOLD_W
    logger.debug('schedule_slot %s', event)
    hass.services.call('system_log', 'write', {'level': 'debug', 'message': f'schedule_slot {event}'}, False)
    return

event = dict(event_base)
event['event'] = 'slot_apply'
msg = f"Schedule runner: slot={minute_index} apply limit {requested_w}W (prev {current_limit_w}W, soc={soc_val:.1f}%, floor={soc_floor_pct}%, dry_run={dry_run})"

if dry_run:
    event['dry_run'] = True
    logger.info('schedule_slot %s', event)
    hass.services.call('system_log', 'write', {'level': 'info', 'message': f'schedule_slot {event}'}, False)
    return

# Apply new power limit using unified signer service (performs its own atRead + interval check)
hass.services.call('solis_signer', 'set_grid_power_limit', {'watts': requested_w, 'threshold_w': THRESHOLD_W}, False)

logger.info('schedule_slot %s', event)
hass.services.call('system_log', 'write', {'level': 'info', 'message': f'schedule_slot {event}'}, False)