from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request, Body
from fastapi.middleware.cors import CORSMiddleware
from app.core.csi_processor import CSIBuffer, SignalProcessor
from app.core.model_manager import ModelManager
from app.api.websocket_handler import manager
from app.core.walrus_client import walrus_client
from datetime import datetime
import numpy as np
import asyncio
import logging

# Setup Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("CSI_Backend")

app = FastAPI(title="CSI Emergency Detection Backend - Walrus Edition")

# In-memory storage for current session (Walrus will be the permanent store)
current_user_profile = {
    "username": "guest",
    "fullName": "Bilinmiyor",
    "age": "-",
    "emergencyContact": "-",
    "chronicDiseases": "-",
    "walrusBlobId": None
}
emergency_history = [] # Local cache of Walrus blob IDs

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Components
csi_buffer = CSIBuffer(window_size_seconds=2, sampling_rate=100)
model_manager = ModelManager(model_path="app/models/model.pkl")

@app.on_event("startup")
async def startup_event():
    model_manager.load_model()
    logger.info("Application started and model loaded.")

@app.post("/profile")
async def update_profile(profile: dict = Body(...)):
    """
    Updates user profile and backups to Walrus.
    """
    global current_user_profile
    current_user_profile.update(profile)
    
    # Backup to Walrus
    blob_id = await walrus_client.publish_blob(current_user_profile, data_type="profile")
    current_user_profile["walrusBlobId"] = blob_id
    
    return {"status": "success", "blobId": blob_id, "profile": current_user_profile}

@app.get("/profile")
async def get_profile():
    return current_user_profile

@app.get("/history")
async def get_history():
    """Returns local cache of emergency events (ideally these would be fetched from Walrus)"""
    return emergency_history

@app.post("/ingest")
async def ingest_csi(request: Request):
    data = await request.json()
    csi_matrix = np.array(data["csi"])
    await csi_buffer.add_packet(csi_matrix)
    magnitude = SignalProcessor.calculate_current_magnitude(csi_matrix)
    
    if csi_buffer.is_full():
        asyncio.create_task(process_and_broadcast(magnitude))
    else:
        await manager.broadcast({
            "magnitude": magnitude,
            "prediction": "Buffering...",
            "confidence": 0.0,
            "is_emergency": False,
            "timestamp": datetime.utcnow().isoformat()
        })
    return {"status": "received"}

async def process_and_broadcast(current_magnitude):
    window_data = await csi_buffer.get_window()
    if window_data:
        processed_window = SignalProcessor.preprocess_window(window_data)
        prediction, confidence = await model_manager.predict(processed_window)
        is_emergency = prediction in ["Düşme", "Hareketsizlik"]
        
        output = {
            "magnitude": current_magnitude,
            "prediction": prediction,
            "confidence": confidence,
            "is_emergency": is_emergency,
            "timestamp": datetime.utcnow().isoformat(),
            "user": current_user_profile["username"]
        }
        
        if is_emergency:
            # Save to Walrus as a permanent record
            blob_id = await walrus_client.publish_blob(output, data_type="event")
            if blob_id:
                output["walrusBlobId"] = blob_id
                emergency_history.insert(0, {
                    "tarih": datetime.now().strftime("%d.%m.%Y %H:%M"),
                    "olay": prediction,
                    "risk": "KRİTİK" if prediction == "Düşme" else "UYARI",
                    "blobId": blob_id
                })
        
        await manager.broadcast(output)

@app.websocket("/ws/monitor")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as e:
        logger.error(f"WebSocket Error: {e}")
        manager.disconnect(websocket)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
