from fastapi import WebSocket
from typing import Dict, List
import json

class ConnectionManager:
    def __init__(self):
        # Maps officer_id -> List of active WebSocket connections
        self.active_connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, officer_id: int, websocket: WebSocket):
        await websocket.accept()
        if officer_id not in self.active_connections:
            self.active_connections[officer_id] = []
        self.active_connections[officer_id].append(websocket)

    def disconnect(self, officer_id: int, websocket: WebSocket):
        if officer_id in self.active_connections:
            if websocket in self.active_connections[officer_id]:
                self.active_connections[officer_id].remove(websocket)
            if not self.active_connections[officer_id]:
                del self.active_connections[officer_id]

    async def send_personal_message(self, message: dict, officer_id: int):
        if officer_id in self.active_connections:
            for connection in self.active_connections[officer_id]:
                try:
                    await connection.send_text(json.dumps(message))
                except Exception as e:
                    print(f"Error sending ws message to {officer_id}: {e}")
                    self.disconnect(officer_id, connection)

manager = ConnectionManager()
