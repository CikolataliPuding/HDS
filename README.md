# CSI Emergency Detection Backend

This repository contains a high-performance Python backend designed for real-time Human Activity Recognition (HAR) using Wi-Fi Channel State Information (CSI). It is specifically optimized for a Flutter mobile application client.

## Features
- **FastAPI Backend**: Asynchronous endpoints for high-frequency data ingestion.
- **WebSocket Integration**: Real-time broadcasting of predictions and signal magnitude.
- **AI Model**: Pre-trained Random Forest model for classifying:
  - **Normal** (Walking, Standing Up)
  - **Düşme** (Falling/Getting Down)
  - **Hareketsizlik** (Standing, Sitting, Lying, Empty Room)
- **High Performance**: Optimized sliding window (2s) at 100Hz.
- **KVKK Compliant**: Raw CSI data is processed in memory and not persisted.

## Project Structure
- `app/main.py`: Main entry point and API logic.
- `app/core/`: Core logic for signal processing and model management.
- `app/api/`: WebSocket handlers.
- `app/models/`: Contains the trained `model.pkl`.
- `scripts/`: Training and simulator scripts.

## Getting Started
1. Install dependencies: `pip install -r requirements.txt`
2. Run the server: `python -m app.main`
3. Use the simulator: `python scripts/simulator.py`

## Client Integration
The Flutter application can subscribe to real-time updates via:
`ws://<server-ip>:8000/ws/monitor`
