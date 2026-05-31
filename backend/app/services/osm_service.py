"""OSM Overpass service — fetches nearby POIs from OpenStreetMap."""
import httpx
import asyncio
from typing import List, Dict, Any
from app.utils.geo import haversine_km

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

# Tag mapping: RoadSOS service type → OSM key=value
OSM_TAG_MAP = {
    "police": "amenity=police",
    "hospital": "amenity=hospital",
    "ambulance": "amenity=ambulance_station",
    "towing": "shop=car_repair",
    "puncture": "shop=tyres",
    "showroom": "shop=car",
}

# Module-level client — reuses TCP connections across requests
_overpass_client = httpx.AsyncClient(
    timeout=20.0,
    limits=httpx.Limits(max_connections=10, max_keepalive_connections=5),
)


async def fetch_nearby_from_osm(
    lat: float, lng: float, service_type: str, radius: int = 15000
) -> List[Dict[str, Any]]:
    """Fetch nearby services from OpenStreetMap Overpass API.

    Free, no API key, global coverage.
    Returns up to 20 results sorted by distance.
    """
    osm_tag = OSM_TAG_MAP.get(service_type, "amenity=hospital")
    tag_key, tag_val = osm_tag.split("=")

    query = f"""
[out:json][timeout:25];
(
  node["{tag_key}"="{tag_val}"](around:{radius},{lat},{lng});
  way["{tag_key}"="{tag_val}"](around:{radius},{lat},{lng});
);
out center 30;
"""

    data = {}
    for attempt in range(2):
        try:
            resp = await _overpass_client.post(
                OVERPASS_URL,
                data={"data": query},
                headers={
                    "Content-Type": "application/x-www-form-urlencoded",
                    "User-Agent": "RoadSOS-App/1.0"
                },
            )
            resp.raise_for_status()
            data = resp.json()
            break
        except (httpx.HTTPStatusError, httpx.TimeoutException, httpx.RequestError) as e:
            if attempt == 1:
                raise e
            await asyncio.sleep(1)

    results: List[Dict[str, Any]] = []
    for el in data.get("elements", []):
        el_lat = el.get("lat") or el.get("center", {}).get("lat", 0)
        el_lng = el.get("lon") or el.get("center", {}).get("lon", 0)
        tags = el.get("tags", {})

        results.append({
            "id": str(el.get("id")),
            "name": tags.get("name") or tags.get("operator") or f"Unknown {service_type}",
            "type": service_type,
            "latitude": el_lat,
            "longitude": el_lng,
            "distance_km": round(haversine_km(lat, lng, el_lat, el_lng), 2),
            "phone": tags.get("phone") or tags.get("contact:phone"),
            "address": tags.get("addr:full") or tags.get("addr:street"),
            "is_open": True,
        })

    results.sort(key=lambda r: r["distance_km"])
    return results[:20]
