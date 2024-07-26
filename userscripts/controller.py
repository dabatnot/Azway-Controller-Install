# MIT License
# 
# Copyright (c) 2024 [Your Name]
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

## @file controller.py
# @brief Script for controlling ESP32 via MQTT.
# @details This script detects an ESP32 device, communicates with it via serial, and processes MQTT messages to send commands to the ESP32.

import serial
import serial.tools.list_ports
import time
import json
import paho.mqtt.client as mqtt
import threading

# MQTT Configuration
BROKER = "127.0.0.1"  # Replace with your MQTT broker address
PORT = 1883
TOPIC = "Recalbox/EmulationStation/EventJson"
#USERNAME = "login"  # Replace with your MQTT username
#PASSWORD = "password"  # Replace with your MQTT password

# Lock to synchronize access to the queue
lock = threading.Lock()
# Variables to store the last received entries
last_entry = None
last_game_entry = None  # To store the last gamelistbrowsing, rungame, or systembrowsing message
# Event to signal a new message
new_message_event = threading.Event()

# Counters for received and processed messages
received_count = 0
processed_count = 0

## @brief Function to detect the ESP32
# @return The detected ESP32 port
def detect_esp32():
    while True:
        ports = list(serial.tools.list_ports.comports())
        for port in ports:
            try:
                ser = serial.Serial(port.device, 115200, timeout=1)
                time.sleep(2)
                ser.reset_input_buffer()  # Clear the input buffer
                ser.write(b'ESP32?')
                time.sleep(1)
                response = ser.readline().strip()  # Use readline() to read the complete response
                print(f"Response received: {response}")
                if response == b'ESP32 ready':
                    print(f"ESP32 detected on port {port.device}")
                    ser.close()
                    return port.device
                ser.close()
            except (serial.SerialException, OSError):
                continue
        print("ESP32 not detected, retrying in 5 seconds...")
        time.sleep(5)

## @brief Function to send a message and wait for ACK
# @param ser Serial object
# @param message Message to send
def send_message(ser, message):
    global processed_count
    ack_received = False
    attempts = 0
    max_attempts = 3
    while not ack_received and attempts < max_attempts:
        ser.write(message.encode())
        time.sleep(1)
        while ser.in_waiting > 0:
            ack = ser.readline().decode('utf-8').strip()
            print(f"Response from ESP32: {ack}")
            if ack == f"ACK:{message}":
                ack_received = True
                processed_count += 1
                print(f"Message processed: {message}")
                return
        attempts += 1
    if not ack_received:
        print(f"Failed to send message after {max_attempts} attempts: {message}")

## @brief Function to process the last message
# @param ser Serial object
def process_message(ser):
    global last_entry

    while True:
        new_message_event.wait()  # Wait for a new message
        with lock:
            if last_entry is None:
                new_message_event.clear()
                continue
            event, nbPlayers = last_entry
            message_content = f"{event}:{nbPlayers}"
            last_entry = None
        new_message_event.clear()
        print(f"Message to send: {message_content}")
        send_message(ser, message_content)

## @brief Callback for receiving MQTT messages
# @param client MQTT client
# @param userdata User data
# @param msg MQTT message
def on_message(client, userdata, msg):
    global last_entry, last_game_entry, received_count
    message = json.loads(msg.payload.decode('utf-8'))
    event = message.get("Action")
    
    # Get the Players value from the Game object if available
    nbPlayers = message.get("Game", {}).get("Players", "1")

    # Extract the last digit of Players if in range format
    if '-' in nbPlayers:
        nbPlayers = nbPlayers.split('-')[-1]
    try:
        nbPlayers = int(nbPlayers)
    except ValueError:
        nbPlayers = 1
    
    # Limit nbPlayers to a maximum of 4
    if nbPlayers < 1:
        nbPlayers = 1
    elif nbPlayers > 4:
        nbPlayers = 4

    event_map = {
        "start": 'S',
        "startgameclip": 'L',
        "gamelistbrowsing": 'N',
        "systembrowsing": 'N',
        "rungame": 'L',
        "endgame": 'Q',
        "system_started": 'D',
        "stop": 'E',
        "shutdown": 'P'
    }

    if event in event_map:
        msg_code = event_map[event]
        with lock:
            if event == "systembrowsing":
                print("Systembrowsing")
                nbPlayers = 4

            last_entry = (msg_code, nbPlayers)
            
            if event in ["gamelistbrowsing", "rungame", "systembrowsing"]:
                last_game_entry = last_entry  # Update the last game message

            message_content = f"{msg_code}:{nbPlayers}"
            received_count += 1
            new_message_event.set()
        print(f"Message received: {message_content}")
    elif event in ["stopgameclip", "wakeup"]:
        with lock:
            if last_game_entry is None:
                # Simulate a systembrowsing event if no relevant message has been received
                last_game_entry = ('N', 4)
            last_entry = last_game_entry
            event, nbPlayers = last_game_entry
            message_content = f"{event}:{nbPlayers}"
            received_count += 1
            new_message_event.set()
            print(f"Special action received ({event}), sending last game message: {message_content}")

# MQTT Configuration
client = mqtt.Client(userdata={"ser": None})
#client.username_pw_set(USERNAME, PASSWORD)
client.on_message = on_message

## @brief Main function to run the script
def main():
    # Detect the ESP32
    esp32_port = detect_esp32()
    
    # Open the serial connection with the detected ESP32
    ser = serial.Serial(esp32_port, 115200)
    time.sleep(2)  # Wait for the connection to establish

    # Pass the serial object to MQTT userdata
    client.user_data_set({"ser": ser})
    
    # Connect to the MQTT broker and subscribe to the topic
    client.connect(BROKER, PORT, 60)
    client.subscribe(TOPIC)

    # Start processing messages in a separate thread
    threading.Thread(target=process_message, args=(ser,), daemon=True).start()

    # Loop to listen for MQTT messages
    client.loop_forever()

if __name__ == "__main__":
    main()
