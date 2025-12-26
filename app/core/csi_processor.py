import numpy as np
from collections import deque
import asyncio
from datetime import datetime

class CSIBuffer:
    def __init__(self, window_size_seconds=2, sampling_rate=50):
        """
        window_size_seconds: 2 seconds as per requirement
        sampling_rate: Expected packets per second (e.g., 50Hz or 100Hz)
        """
        self.max_len = int(window_size_seconds * sampling_rate)
        self.buffer = deque(maxlen=self.max_len)
        self.lock = asyncio.Lock()

    async def add_packet(self, csi_matrix):
        """
        csi_matrix: numpy array of shape (subcarriers, antennas) or similar
        """
        async with self.lock:
            # We store the magnitude immediately to save memory and processing time later
            # This aligns with KVKK requirement: process and don't store raw if possible
            magnitude = np.abs(csi_matrix)
            self.buffer.append({
                "magnitude": magnitude,
                "timestamp": datetime.utcnow()
            })

    async def get_window(self):
        async with self.lock:
            if len(self.buffer) < self.max_len:
                return None
            return list(self.buffer)

    def is_full(self):
        return len(self.buffer) == self.max_len

class SignalProcessor:
    @staticmethod
    def preprocess_window(window_data):
        """
        Prepares the windowed data for the AI model.
        window_data: List of dicts with 'magnitude'
        """
        # Stack magnitudes into a single matrix (time, subcarriers, antennas)
        magnitudes = [d["magnitude"] for d in window_data]
        window_matrix = np.stack(magnitudes)
        
        # Normalize or reshape based on model requirements
        # Example: window_matrix = (window_matrix - np.mean(window_matrix)) / np.std(window_matrix)
        
        return window_matrix

    @staticmethod
    def calculate_current_magnitude(csi_matrix):
        """Returns the mean magnitude of the current packet for monitoring"""
        return float(np.mean(np.abs(csi_matrix)))
