from fastapi import FastAPI, WebSocket, WebSocketDisconnect, BackgroundTasks, Request
from fastapi.middleware.cors import CORSMiddleware
from app.core.csi_processor import CSIBuffer, SignalProcessor
from app.core.model_manager import ModelManager
from app.api.websocket_handler import manager
from datetime import datetime
import numpy as np
import asyncio
import logging

# Setup Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("CSI_Backend")

app = FastAPI(title="CSI Emergency Detection Backend")

# CORS for Flutter web or other clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Components
# Sampling rate 100Hz as per dataset context/simulator, 2s window = 200 packets.
csi_buffer = CSIBuffer(window_size_seconds=2, sampling_rate=100)
model_manager = ModelManager(model_path="app/models/model.pkl")

@app.on_event("startup")
async def startup_event():
    model_manager.load_model()
    logger.info("Application started and model loaded.")

@app.post("/ingest")
async def ingest_csi(request: Request):
    """
    Endpoint for ESP32 to send CSI data.
    Expects JSON or binary data. For this example, we'll assume JSON array.
    """
    data = await request.json()
    # Assume data is a list representing the CSI matrix
    csi_matrix = np.array(data["csi"])
    
    # Add to buffer
    await csi_buffer.add_packet(csi_matrix)
    
    # Quick magnitude for immediate feedback
    magnitude = SignalProcessor.calculate_current_magnitude(csi_matrix)
    
    # If buffer is full, trigger inference in background (or inline if fast enough)
    if csi_buffer.is_full():
        asyncio.create_task(process_and_broadcast(magnitude))
    else:
        # Just broadcast magnitude if not enough data for prediction yet
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
            "timestamp": datetime.utcnow().isoformat()
        }
        
        await manager.broadcast(output)

@app.websocket("/ws/monitor")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            # Keep connection alive
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as e:
        logger.error(f"WebSocket Error: {e}")
        manager.disconnect(websocket)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
