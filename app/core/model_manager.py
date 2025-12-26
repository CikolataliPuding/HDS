import os
import joblib
import numpy as np
import logging

class ModelManager:
    def __init__(self, model_path="app/models/model.pkl"):
        self.model_path = model_path
        self.model = None
        self.logger = logging.getLogger("ModelManager")

    def load_model(self):
        """
        Loads the scikit-learn model from a .pkl file.
        """
        if os.path.exists(self.model_path):
            try:
                self.model = joblib.load(self.model_path)
                self.logger.info(f"Model loaded successfully from {self.model_path}")
            except Exception as e:
                self.logger.error(f"Error loading model: {e}")
                self.model = None
        else:
            self.logger.warning(f"Model file {self.model_path} not found. Using mock inference.")
            self.model = None

    async def predict(self, processed_window):
        """
        Performs inference on the processed window.
        processed_window: numpy array (100, 1026) or similar.
        
        Since the model was trained on individual rows of 1026 features, 
        we will take the mean of the window features for inference.
        """
        if self.model is None:
            # Fallback to mock if model didn't load
            classes = ["Normal", "Düşme", "Hareketsizlik"]
            prediction = np.random.choice(classes, p=[0.8, 0.1, 0.1])
            confidence = float(np.random.uniform(0.7, 0.99))
            return prediction, confidence
        
        try:
            # If processed_window is (window_size, features), take the mean across the window
            # to get a single vector of 1026 features.
            if processed_window.ndim > 1:
                input_data = np.mean(processed_window, axis=0).reshape(1, -1)
            else:
                input_data = processed_window.reshape(1, -1)
            
            prediction = self.model.predict(input_data)[0]
            # Random Forest doesn't always give simple confidence, use predict_proba
            probabilities = self.model.predict_proba(input_data)[0]
            confidence = float(np.max(probabilities))
            
            return str(prediction), confidence
        except Exception as e:
            self.logger.error(f"Inference error: {e}")
            return "Normal", 0.0
