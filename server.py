import os
import pandas as pd
import numpy as np
import time
from keras.models import load_model
from keras.utils import CustomObjectScope
from keras.initializers import glorot_uniform
import keras

# Dummy model for prototype - replace with real model later
class DummyModel:
    def predict(self, data):
        # Simple dummy logic: random prediction
        return [[0.3, 0.7]]  # [no_fall_prob, fall_prob]

def einlesen(model):
    pfad = "\\Filezilla"  # Change to your FTP folder path
    
    # Initialize with empty dataframes
    try:
        last_data = pd.read_csv(pfad+"\\anlauf2.csv", usecols=["rel_time","acc_x","acc_y","acc_z","gyro_x","gyro_y","gyro_z","azimuth","pitch","roll"])
        last_data2 = pd.read_csv(pfad+"\\anlauf.csv", usecols=["rel_time","acc_x","acc_y","acc_z","gyro_x","gyro_y","gyro_z","azimuth","pitch","roll"])
    except:
        # Create empty dataframes if files don't exist
        cols = ["rel_time","acc_x","acc_y","acc_z","gyro_x","gyro_y","gyro_z","azimuth","pitch","roll"]
        last_data = pd.DataFrame(columns=cols)
        last_data2 = pd.DataFrame(columns=cols)
    
    while True:
        if os.path.exists(pfad+"\\test.csv"):
            try:
                data = pd.read_csv(pfad+"\\test.csv", usecols=["rel_time","acc_x","acc_y","acc_z","gyro_x","gyro_y","gyro_z","azimuth","pitch","roll"])
                
                if len(data) >= 2001 and len(last_data) > 1998:
                    if data.at[1998,"acc_x"] != last_data.at[1998,"acc_x"]:
                        time.sleep(0.2)
                        last_data = data
                        print("New data detected:", len(data), "rows")
                        test_data = daten_verarbeitung(last_data, last_data2)
                        daten_prufen(model, test_data)
            except Exception as e:
                print("Error reading test.csv:", e)
                continue
        
        if os.path.exists(pfad+"\\test2.csv"):
            try:    
                data2 = pd.read_csv(pfad+"\\test2.csv", usecols=["rel_time","acc_x","acc_y","acc_z","gyro_x","gyro_y","gyro_z","azimuth","pitch","roll"])
                
                if len(data2) >= 2001 and len(last_data2) > 1998:
                    if data2.at[1998,"acc_x"] != last_data2.at[1998,"acc_x"]:
                        time.sleep(0.2)
                        last_data2 = data2
                        print("New data detected:", len(data2), "rows")
                        test_data = daten_verarbeitung(last_data, last_data2)
                        daten_prufen(model, test_data)
            except Exception as e:
                print("Error reading test2.csv:", e)
                continue
        
        time.sleep(1)  # Check every second

def daten_verarbeitung(last_data, last_data2):
    test_data = []
    
    if len(last_data) == 0 or len(last_data2) == 0:
        return test_data
    
    if last_data.at[1,"rel_time"] < last_data2.at[1,"rel_time"]:
        last_data = pd.concat([last_data, last_data2])
        print("Combined data shape:", last_data.shape)
        for i in range(1, min(2000, len(last_data)-2000)):
            if i+2000 <= len(last_data):
                test_data.append(last_data[["acc_x","acc_y","acc_z","gyro_x","gyro_y","gyro_z","azimuth","pitch","roll"]].values[i:2000+i])
    else:
        last_data2 = pd.concat([last_data2, last_data])
        print("Combined data shape:", last_data2.shape)
        for i in range(1, min(2000, len(last_data2)-2000)):
            if i+2000 <= len(last_data2):
                test_data.append(last_data[["acc_x","acc_y","acc_z","gyro_x","gyro_y","gyro_z","azimuth","pitch","roll"]].values[i:2000+i])
    
    return test_data

def daten_prufen(model, test_data):
    if not test_data:
        print("No test data to process")
        return
        
    labels = []    
    
    for i in range(len(test_data)):
        test = []
        test.append(test_data[i])
        test = keras.preprocessing.sequence.pad_sequences(test, maxlen=7999, dtype='float32', padding='pre', truncating='pre', value=0.0)
        test = np.array(test)
        
        predictions = model.predict(test)
        
        if np.argmax(predictions) == 1:
            labels.append(1)
        else:
            labels.append(0)
    
    labels = np.array(labels)
    print("Predictions - Max:", np.max(labels), "Min:", np.min(labels))
    
    if np.mean(labels) > 0.5:
        print("FALL DETECTED! Confidence:", np.mean(labels))
    else:
        print("Normal Activity. Confidence:", 1 - np.mean(labels))

# Load model (using dummy for prototype)
print("Loading model...")
try:
    # Uncomment when you have real model:
    # with CustomObjectScope({'GlorotUniform': glorot_uniform()}):
    #     model = load_model('Model.pb')
    
    # For now, use dummy model:
    model = DummyModel()
    print("Dummy model loaded successfully")
except:
    print("Using dummy model")
    model = DummyModel()

print("Starting fall detection server...")
einlesen(model)
