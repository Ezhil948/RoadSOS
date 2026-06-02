import os
import base64
import httpx
from typing import List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.db_models import SOSAlert

class StorageService:
    def __init__(self, api_key: str = None):
        self.api_key = api_key or os.getenv("IMGBB_API_KEY")

    async def upload_photos_task(self, alert_id: int, photos: List[str], db: AsyncSession):
        """Upload base64 encoded photos to ImgBB and update the SOS alert in the database."""
        if not self.api_key:
            print("Warning: IMGBB_API_KEY is not set. Photo upload skipped.")
            return

        try:
            photo_urls = []
            async with httpx.AsyncClient(timeout=30.0) as client:
                for idx, b64_str in enumerate(photos):
                    try:
                        if "," in b64_str:
                            b64_str = b64_str.split(",")[1]
                        file_bytes = base64.b64decode(b64_str)
                        files = {"image": (f"incident_{alert_id}_{idx}.jpg", file_bytes, "image/jpeg")}
                        res = await client.post(
                            f"https://api.imgbb.com/1/upload?key={self.api_key}", 
                            files=files
                        )
                        if res.status_code == 200:
                            url = res.json().get("data", {}).get("url")
                            if url:
                                photo_urls.append(url)
                    except Exception as e:
                        print(f"ImgBB upload error: {e}")
            
            if photo_urls:
                result = await db.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
                alert = result.scalar_one_or_none()
                if alert:
                    alert.closure_photo_urls = photo_urls
                    await db.commit()
        finally:
            await db.close()
