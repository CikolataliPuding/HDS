import asyncio
import websockets
import requests
import json
import numpy as np
import time
from datetime import datetime

BACKEND_URL = "http://localhost:8000"
WS_URL = "ws://localhost:8000/ws/monitor"

async def monitor_websocket():
    try:
        async with websockets.connect(WS_URL) as websocket:
            print(f"[{datetime.now()}] Connected to WebSocket")
            while True:
                message = await websocket.recv()
                data = json.loads(message)
                print(f"[{data['timestamp']}] Prediction: {data['prediction']} | Confidence: {data['confidence']:.2f} | Mag: {data['magnitude']:.4f} | Emergency: {data['is_emergency']}")
    except Exception as e:
        print(f"WebSocket Error: {e}")

async def simulate_esp32():
    print(f"[{datetime.now()}] Starting ESP32 Simulation")
    # Wait a bit for WS to connect
    await asyncio.sleep(2)
    
    # Simulate 50 packets per second
    while True:
        # Generate mock CSI matrix matching the trained model (1026 features)
        # Random data to simulate real sensor input
        csi_matrix = np.random.normal(0, 1, (1026,))
        
        payload = {
            "csi": csi_matrix.tolist()
        }
        
        try:
            # Send to ingest endpoint
            response = requests.post(f"{BACKEND_URL}/ingest", json={"csi": csi_matrix.tolist()})
            if response.status_code != 200:
                print(f"Ingest Error: {response.text}")
        except Exception as e:
            print(f"Request Error: {e}")
        
        # Simulate 100 packets per second (10ms delay)
        await asyncio.sleep(0.01) 

async def main():
    # Run both simulator and monitor
    await asyncio.gather(
        monitor_websocket(),
        simulate_esp32()
    )

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Simulator stopped.")
