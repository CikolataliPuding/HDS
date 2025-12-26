import httpx
import json
import logging
from datetime import datetime

logger = logging.getLogger("WalrusClient")

class WalrusClient:
    def __init__(self, publisher_url="https://publisher.walrus-testnet.walrus.space", aggregator_url="https://aggregator.walrus-testnet.walrus.space"):
        self.publisher_url = publisher_url.rstrip("/")
        self.aggregator_url = aggregator_url.rstrip("/")

    async def publish_blob(self, data: dict, data_type: str = "event"):
        """
        Publishes data to Walrus as a blob.
        data_type: 'event' or 'profile'
        """
        url = f"{self.publisher_url}/v1/blobs"
        
        payload = {
            "type": data_type,
            "data": data,
            "system_metadata": {
                "source": "CSI_Emergency_System",
                "timestamp": datetime.utcnow().isoformat(),
                "network": "testnet"
            }
        }

        try:
            async with httpx.AsyncClient() as client:
                response = await client.put(
                    url, 
                    content=json.dumps(payload),
                    params={"epochs": 5}, # Store for longer (5 epochs)
                    timeout=30.0
                )
                
                if response.status_code in [200, 201]:
                    result = response.json()
                    blob_id = result.get("newBlob", {}).get("blobId") or result.get("alreadyCertified", {}).get("blobId")
                    logger.info(f"Published {data_type} to Walrus. Blob ID: {blob_id}")
                    return blob_id
                else:
                    logger.error(f"Failed to publish {data_type} to Walrus: {response.status_code} - {response.text}")
                    return None
        except Exception as e:
            logger.error(f"Walrus publication error: {e}")
            return None

    async def read_blob(self, blob_id: str):
        """
        Reads a blob from Walrus aggregator.
        """
        url = f"{self.aggregator_url}/v1/blobs/{blob_id}"
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(url, timeout=30.0)
                if response.status_code == 200:
                    return response.json()
                else:
                    logger.error(f"Failed to read blob {blob_id}: {response.status_code}")
                    return None
        except Exception as e:
            logger.error(f"Walrus read error: {e}")
            return None

# Singleton instance
walrus_client = WalrusClient()
