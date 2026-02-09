"""Poll SolisCloud atRead and store result in input_text helper."""
import logging

logger = logging.getLogger(__name__)

# Get service parameters from automation data
cid = data.get("cid")  # noqa: F821 - data is injected by Home Assistant
entity_id = data.get("entity_id")  # noqa: F821

if not cid or not entity_id:
    logger.error(f"poll_solis_atread: Missing cid or entity_id parameter: cid={cid}, entity_id={entity_id}")
    return  # noqa: F821 - valid in Python script context

logger.debug(f"poll_solis_atread: Polling CID {cid} and storing in {entity_id}")

# Call the solis_signer.post service
try:
    result = hass.call_service("solis_signer", "post", {  # noqa: F821
        "path": "/v2/api/atRead",
        "payload": {"cid": cid}
    }, blocking=True)
    
    logger.debug(f"CID {cid} response: {result}")
    
    # Extract yuanzhi value from response
    yuanzhi = "0"
    if result and isinstance(result, dict):
        data_obj = result.get("data")
        if isinstance(data_obj, dict):
            yuanzhi_raw = data_obj.get("yuanzhi")
            if yuanzhi_raw:
                yuanzhi = str(int(float(str(yuanzhi_raw))))
                logger.info(f"CID {cid}: yuanzhi = {yuanzhi}")
    
    # Set the input_text entity with the value
    hass.call_service("input_text", "set_value", {  # noqa: F821
        "entity_id": entity_id,
        "value": yuanzhi
    }, blocking=True)
    
    logger.info(f"poll_solis_atread: Set {entity_id} = {yuanzhi}")
    
except Exception as e:  # noqa: F841
    logger.error(f"poll_solis_atread: Error polling CID {cid}: {e}", exc_info=True)

