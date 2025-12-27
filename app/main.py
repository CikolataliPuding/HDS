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
import random
import time

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

# --- Fake CSI live feed (for Flutter /live_data demo) ---
live_data_cache = {
    "signal": 2.0,
    "status": "SAFE",  # SAFE | DANGER | FALL
    "timestamp": datetime.utcnow().isoformat(),
    "walrusBlobId": None,
}

_fake_mode = "SAFE"
_fake_mode_until = 0.0
_fake_next_event_at = 0.0
_fake_last_published_at = 0.0
_fake_last_blob_id = None

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
    # start fake live feed for /live_data demo
    asyncio.create_task(fake_live_data_loop())

@app.get("/live_data")
async def live_data():
    """
    Flutter demo endpoint.
    Returns: {"signal": float, "status": "SAFE|DANGER|FALL", "timestamp": str, "walrusBlobId": str|null}
    """
    return live_data_cache

@app.post("/profile")
async def update_profile(profile: dict = Body(...)):
    """
    Updates user profile and backups to Walrus.
    """
    global current_user_profile
    current_user_profile.update(profile)
    
    # Backup to Walrus
    blob_id = await walrus_client.publish_blob(current_user_profile, data_type="profile", epochs=1)
    current_user_profile["walrusBlobId"] = blob_id
    
    return {"status": "success", "blobId": blob_id, "profile": current_user_profile}

@app.get("/profile")
async def get_profile():
    return current_user_profile

@app.get("/history")
async def get_history():
    """Returns local cache of emergency events (ideally these would be fetched from Walrus)"""
    return emergency_history

@app.post("/walrus/test_event")
async def walrus_test_event(payload: dict = Body(default={})):
    """
    ACİL: Hemen bir Walrus blobId üretmek için.
    Opsiyonel payload: {"risk":"KRİTİK|UYARI", "note":"..."}
    """
    risk = (payload.get("risk") or "KRİTİK").upper()
    note = (payload.get("note") or "manual_test_event").strip()

    event = {
        "magnitude": float(live_data_cache.get("signal", 0.0)),
        "prediction": "Düşme" if risk == "KRİTİK" else "Hareketsizlik",
        "confidence": 1.0,
        "is_emergency": True,
        "timestamp": datetime.utcnow().isoformat(),
        "user": current_user_profile.get("username", "guest"),
        "source": "manual_test_event",
        "note": note,
    }

    blob_id = await walrus_client.publish_blob(event, data_type="event")
    if blob_id:
        live_data_cache["walrusBlobId"] = blob_id
        emergency_history.insert(0, {
            "tarih": datetime.now().strftime("%d.%m.%Y %H:%M"),
            "olay": event["prediction"],
            "risk": risk,
            "blobId": blob_id
        })
    return {"blobId": blob_id, "event": event}

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
            blob_id = await walrus_client.publish_blob(output, data_type="event", epochs=1)
            if blob_id:
                output["walrusBlobId"] = blob_id
                emergency_history.insert(0, {
                    "tarih": datetime.now().strftime("%d.%m.%Y %H:%M"),
                    "olay": prediction,
                    "risk": "KRİTİK" if prediction == "Düşme" else "UYARI",
                    "blobId": blob_id
                })
        
        await manager.broadcast(output)

async def _publish_fake_emergency(status: str, signal: float):
    """
    Publish a fake emergency event to Walrus and update local history/cache.
    """
    global _fake_last_blob_id, _fake_last_published_at

    # throttle publishing (avoid spamming Walrus)
    now = time.monotonic()
    if now - _fake_last_published_at < 10.0:
        return

    event = {
        "magnitude": float(signal),
        "prediction": "Düşme" if status == "FALL" else "Hareketsizlik",
        "confidence": 1.0,
        "is_emergency": True,
        "timestamp": datetime.utcnow().isoformat(),
        "user": current_user_profile.get("username", "guest"),
        "source": "fake_csi_wave",
    }

    blob_id = await walrus_client.publish_blob(event, data_type="event", epochs=1)
    if blob_id:
        _fake_last_published_at = now
        _fake_last_blob_id = blob_id

        emergency_history.insert(0, {
            "tarih": datetime.now().strftime("%d.%m.%Y %H:%M"),
            "olay": event["prediction"],
            "risk": "KRİTİK" if status == "FALL" else "UYARI",
            "blobId": blob_id
        })

async def fake_live_data_loop():
    """
    Generates a smooth wave-like signal, occasionally producing DANGER/FALL.
    Designed for Flutter polling /live_data every ~100ms.
    """
    global _fake_mode, _fake_mode_until, _fake_next_event_at

    # schedule first event a bit later
    start = time.monotonic()
    _fake_next_event_at = start + random.uniform(6.0, 12.0)

    while True:
        now = time.monotonic()

        # transition logic
        if _fake_mode == "SAFE" and now >= _fake_next_event_at:
            _fake_mode = random.choice(["DANGER", "FALL"])
            _fake_mode_until = now + random.uniform(3.0, 6.0)
            _fake_next_event_at = _fake_mode_until + random.uniform(10.0, 22.0)
            # publish once per emergency episode (async, don't block the loop too long)
            asyncio.create_task(_publish_fake_emergency(_fake_mode, live_data_cache["signal"]))
        elif _fake_mode in ("DANGER", "FALL") and now >= _fake_mode_until:
            _fake_mode = "SAFE"

        # generate wave-like signal
        t = now - start
        base = 2.2 + 0.35 * np.sin(t * 1.7) + 0.20 * np.sin(t * 0.35)
        noise = np.random.normal(0.0, 0.12)
        signal = base + noise

        if _fake_mode == "DANGER":
            # elevated + jitter
            signal = signal + 3.0 + abs(np.random.normal(0.0, 0.7))
        elif _fake_mode == "FALL":
            # sharp spike behavior
            signal = signal + 6.0 + abs(np.random.normal(0.0, 1.0))

        signal = float(np.clip(signal, 0.0, 10.0))

        live_data_cache["signal"] = signal
        live_data_cache["status"] = _fake_mode if _fake_mode != "SAFE" else "SAFE"
        live_data_cache["timestamp"] = datetime.utcnow().isoformat()
        live_data_cache["walrusBlobId"] = _fake_last_blob_id

        # Optional: also broadcast to websocket so other clients can subscribe
        try:
            await manager.broadcast({
                "magnitude": signal,
                "prediction": "FALL" if live_data_cache["status"] == "FALL" else ("DANGER" if live_data_cache["status"] == "DANGER" else "SAFE"),
                "confidence": 1.0,
                "is_emergency": live_data_cache["status"] in ("DANGER", "FALL"),
                "timestamp": live_data_cache["timestamp"],
                "walrusBlobId": _fake_last_blob_id,
            })
        except Exception:
            pass

        await asyncio.sleep(0.1)

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
