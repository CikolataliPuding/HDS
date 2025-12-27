# CSI Emergency Detection & Walrus Decentralized Storage

This project is a high-performance system for Human Activity Recognition (HAR) using Wi-Fi Channel State Information (CSI). It features a FastAPI backend, a Flutter frontend, and **Mysten Labs Walrus** for decentralized data persistence.

---

## 🚀 Execution Guide (For Humans & AI Agents)

To run this project, follow these steps in order.

### 1. Prerequisites
- **Python 3.9+**
- **Flutter SDK** (Channel stable)
- **Git**

### 2. Backend Setup
The backend manages signal processing, AI inference, and Walrus publication.

```bash
# Navigate to project root
pip install -r requirements.txt

# Run the FastAPI server
# This will start the server on http://localhost:8000
python -m app.main
```
- **Note**: The model is loaded from `app/models/model.pkl` on startup.
- **Port**: `8000` (FastAPI)
- **Websocket**: `ws://localhost:8000/ws/monitor`

### 3. Data Simulation (ESP32 Mock)
If you don't have an ESP32 device, use the simulator to feed real data patterns into the backend.

```bash
# In a new terminal
python scripts/simulator.py
```
- The simulator sends CSI matrices to `http://localhost:8000/ingest`.

### 4. Frontend Setup (Flutter)
The frontend provides real-time monitoring and profile management.

```bash
# Ensure you are at the project root (where pubspec.yaml is)
flutter pub get

# Run the application
flutter run
```
- **Configuration**: The app connects to `localhost:8000` by default.

---

## 🛠 Testing & Verification Flow

To verify the **Walrus Integration** and end-to-end logic:

1. **User Profile**:
   - Open the Flutter app.
   - Click the **Profile** (Person Icon) leading to `ProfilSayfasi`.
   - Fill in Ad Soyad, Yaş, etc., and click **WALRUS'A KAYDET**.
   - Check backend logs; you should see: `Published profile to Walrus. Blob ID: <ID>`.

2. **Emergency Detection**:
   - Ensure `simulator.py` is running.
   - Wait for a "Düşme" (Fall) prediction (triggered by high magnitude in the simulator).
   - The app will flash red and show "ACİL DURUM".
   - The event will be automatically published to Walrus as a blob.

3. **History (Decentralized Logs)**:
   - Click the **History** (Clock Icon) on the main screen.
   - You will see the list of incidents fetched from the backend, including their unique **Walrus Blob IDs**.

---

## 🧠 Technical Details for AI Assistants (Cursor/Antigravity)
- **Entry Point**: `app/main.py` (FastAPI app).
- **Core Logic**: `app/core/csi_processor.py` for sliding window.
- **Model Logic**: `app/core/model_manager.py` (loads `joblib` pickle).
- **Walrus Client**: `app/core/walrus_client.py` using `httpx`.
- **UI Logic**: `lib/main.dart`.
- **Dependencies**: `httpx`, `fastapi`, `uvicorn`, `scikit-learn`, `joblib`, `numpy`.

---

## 🔗 Repository
[https://github.com/CikolataliPuding/HDS](https://github.com/CikolataliPuding/HDS)
