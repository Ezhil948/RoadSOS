import asyncio
import httpx
from datetime import datetime

async def test_scenario():
    print("Testing dispatch continuous scan scenario...")
    async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
        # 1. Trigger SOS
        res = await client.post("/api/v1/sos/alert", json={
            "latitude": 10.0,
            "longitude": 10.0,
            "severity": "critical",
            "message": "Help!",
            "device_id": "test_device"
        })
        print("SOS Trigger:", res.json())
        alert_id = res.json()["alert_id"]

        # 2. Check alert status immediately (simulating citizen app)
        res = await client.get(f"/api/v1/sos/alerts/{alert_id}/status")
        print("Initial Status:", res.json())

        # 3. Bring an officer online
        print("Bringing Officer 1 online...")
        res = await client.post("/api/v1/dispatch/officers/1/ping", json={
            "latitude": 10.001,
            "longitude": 10.001,
            "status": "available"
        })
        print("Officer Ping:", res.json())

        # 4. Wait for the 10-second polling window condition: int(delta) % 10 < 5
        print("Waiting for citizen app to poll again (simulated)...")
        # Let's just manually call the status endpoint a few times
        for i in range(5):
            await asyncio.sleep(2)
            res = await client.get(f"/api/v1/sos/alerts/{alert_id}/status")
            status_data = res.json()
            print(f"Poll {i+1}:", status_data)

        # 5. Check if Officer 1 got the dispatch
        res = await client.get("/api/v1/dispatch/officers/1/dispatch")
        print("Officer Dispatch Poll:", res.json())

if __name__ == "__main__":
    asyncio.run(test_scenario())
