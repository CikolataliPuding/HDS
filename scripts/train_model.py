import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, accuracy_score
import joblib
import os

# Paths
DATA_PATH = "data/dataset/data.csv"
LABEL_PATH = "data/dataset/label.csv"
MODEL_PATH = "app/models/model.pkl"

def train():
    print("Loading data...")
    # Load data (no header in data.csv based on peak)
    X = pd.read_csv(DATA_PATH, header=None)
    # Load labels
    y_raw = pd.read_csv(LABEL_PATH, header=None, names=["Index", "Label"])
    y = y_raw["Label"]

    # Align X and y in case of mismatch
    min_rows = min(len(X), len(y))
    X = X.iloc[:min_rows]
    y = y.iloc[:min_rows]

    print(f"Data shape after alignment: {X.shape}")

    # 1. Map labels to user requirements: Düşme, Hareketsizlik, Normal
    # Mapping logic:
    # get_down -> Düşme
    # sitting, lying, standing, no_person -> Hareketsizlik
    # walking, get_up -> Normal
    
    mapping = {
        "get_down": "Düşme",
        "sitting": "Hareketsizlik",
        "lying": "Hareketsizlik",
        "standing": "Hareketsizlik",
        "no_person": "Hareketsizlik",
        "walking": "Normal",
        "get_up": "Normal"
    }
    
    y_mapped = y.map(mapping)
    
    print(f"Mapped Labels distribution:\n{y_mapped.value_counts()}")

    # 2. Split data
    X_train, X_test, y_train, y_test = train_test_split(X, y_mapped, test_size=0.2, random_state=42)

    # 3. Train Model
    print("Training Random Forest model...")
    model = RandomForestClassifier(n_estimators=100, random_state=42, n_jobs=-1)
    model.fit(X_train, y_train)

    # 4. Evaluate
    y_pred = model.predict(X_test)
    print(f"Accuracy: {accuracy_score(y_test, y_pred)}")
    print("Classification Report:")
    print(classification_report(y_test, y_pred))

    # 5. Save Model
    print(f"Saving model to {MODEL_PATH}...")
    os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
    joblib.dump(model, MODEL_PATH)
    print("Training complete.")

if __name__ == "__main__":
    train()
