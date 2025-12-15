# AAdded a shared StateMachineManager 
from PyQt6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                            QHBoxLayout, QPushButton, QLabel, QComboBox, 
                            QGroupBox, QLineEdit, QMessageBox, QTabWidget,  
                            QTableWidget, QTableWidgetItem, QProgressBar,
                            QFileDialog, QTextEdit)
from PyQt6.QtCore import Qt, QThread, pyqtSignal
import os
import sys
import time
import serial
import threading
import queue
import pandas as pd
from datetime import datetime
import re

# Add preprocessing functions from the module in the parent directory
path_to_main_modules = os.path.abspath(os.path.join(os.path.dirname(__file__), '..','..','..'))
support_functions_path = os.path.abspath(os.path.join(os.path.dirname(__file__), 'SupportFunctions'))

sys.path.append( os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
sys.path.append(support_functions_path)
import Preprocessing as preprocess
import FPGA_Interface as fpga
import Postprocessing as postprocess

# Importing the GUI modules, the different tabs
from GUI_Graphics import StateCircle
import GUI_send_from_dic as pre_def 


class SerialConnectionManager:
    """Manages serial connection for the application"""
    def __init__(self, port_combo, baudrate_combo, connect_button, status_label):
        self.port_combo = port_combo
        self.baudrate_combo = baudrate_combo
        self.connect_button = connect_button
        self.status_label = status_label
        self.serial_connection = None
        
        # Setup initial state
        if self.connect_button:
            self.connect_button.clicked.connect(self.connect_serial)
        
    def connect_serial(self):
        """Connect to the serial port"""
        port = self.port_combo.currentText()
        baudrate = int(self.baudrate_combo.currentText())
        try:
            self.serial_connection = serial.Serial(port, baudrate)
            self.status_label.setText(f"Connected to {port} at {baudrate} baud")
            self.connect_button.setText("Disconnect")
            self.connect_button.clicked.disconnect()
            self.connect_button.clicked.connect(self.disconnect_serial)
            return True
        except serial.SerialException as e:
            self.status_label.setText(f"Error: {e}")
            return False

    def disconnect_serial(self):
        """Disconnect from the serial port"""
        if self.serial_connection:
            self.serial_connection.close()
            self.serial_connection = None
        self.status_label.setText("Disconnected")
        self.connect_button.setText("Connect")
        self.connect_button.clicked.disconnect()
        self.connect_button.clicked.connect(self.connect_serial)
    
    def write_to_fpga(self, data):
        """Write data to the FPGA via serial connection"""
        if self.serial_connection:
            try:
                # Convert the integer to 4 bytes (32 bits)
                data_bytes = data.to_bytes(4, byteorder='big')
                self.serial_connection.write(data_bytes)
                self.serial_connection.flush()  # Ensure all data is sent
                time.sleep(0.1)  # Add a small delay (100ms) to ensure the buffer is processed
                return True
            except Exception as e:
                if self.status_label:
                    self.status_label.setText(f"Error writing to serial port: {e}")
                return False
        else:
            if self.status_label:
                self.status_label.setText("Not connected to serial port")
            return False
        
class StateMachineManager:
    """Manages the state machine for the application."""
    def __init__(self, connection_manager):
        self.connection_manager = connection_manager
        self.current_state = None

        # Define state values (using binary strings for transitions)
        self.state_ID = '0' * 7 + '1'
        self.states = {
            'Idle': self.state_ID + '0' * 24,               # Idle state
            'Initialization': self.state_ID + '0' * 23 + '1',       # Init state
            'Verification': self.state_ID + '0' * 22 + '10', # Verification state
            'Simulation': self.state_ID + '0' * 22 + '11',   # Simulation state
            'Pause': self.state_ID + '0' * 21 + '100'       # Pause state
        }

    def transition_to_state(self, state_name):
        """Change the state machine state."""
        if state_name not in self.states:
            raise ValueError(f"Invalid state: {state_name}")

        state_value = self.states[state_name]
        binary_value = int(state_value, 2)

        # Use the connection manager to write to FPGA
        if self.connection_manager.write_to_fpga(binary_value):
            self.current_state = state_name
            return f"Transitioned to {state_name} state"
        else:
            raise RuntimeError(f"Failed to transition to {state_name} state")

    def get_current_state(self):
        """Get the current state of the state machine."""
        return self.current_state
    
class ConnectionTab(QWidget):
    """Tab for managing serial connection and state machine control."""
    def __init__(self, connection_manager, parent=None):
        super().__init__(parent)
        self.connection_manager = connection_manager
        self.state_machine_manager = StateMachineManager(connection_manager)
        self.setup_ui()

    def setup_ui(self):
        layout = QVBoxLayout(self)

        # Serial connection setup
        connection_group = QGroupBox("Serial Connection")
        connection_layout = QHBoxLayout()

        self.port_combo = QComboBox()
        self.port_combo.addItems(["/dev/ttyUSB0", "/dev/ttyUSB1", "/dev/ttyUSB2", "COM1", "COM2", "COM3"])
        self.port_combo.setEditable(True)

        self.baudrate_combo = QComboBox()
        self.baudrate_combo.addItems(["9600", "19200", "38400", "57600", "115200"])
        self.baudrate_combo.setCurrentText("115200")

        self.connect_button = QPushButton("Connect")

        connection_layout.addWidget(QLabel("Port:"))
        connection_layout.addWidget(self.port_combo)
        connection_layout.addWidget(QLabel("Baudrate:"))
        connection_layout.addWidget(self.baudrate_combo)
        connection_layout.addWidget(self.connect_button)
        connection_group.setLayout(connection_layout)

        layout.addWidget(connection_group)

        # State transition buttons
        buttons_layout = QHBoxLayout()
        for state_name in ["Idle", "Initialization", "Verification", "Simulation", "Pause"]:
            button = QPushButton(f"Go to {state_name}")
            button.clicked.connect(lambda checked, s=state_name: self.transition_to_state(s))
            buttons_layout.addWidget(button)
        layout.addLayout(buttons_layout)

        # Status indicator
        self.status_label = QLabel("Not connected")
        layout.addWidget(self.status_label)

    def transition_to_state(self, state_name):
        """Change the state machine state."""
        try:
            message = self.state_machine_manager.transition_to_state(state_name)
            self.status_label.setText(message)
        except Exception as e:
            self.status_label.setText(f"Error: {e}")

    def get_state_machine_manager(self):
        """Return the state machine manager for use by other tabs."""
        return self.state_machine_manager
    

class CustomSignalTab(QWidget):
    """Tab for sending custom signals."""
    def __init__(self, connection_manager, state_machine_manager, parent=None):
        super().__init__(parent)
        self.connection_manager = connection_manager
        self.state_machine_manager = state_machine_manager
        self.setup_ui()

    def setup_ui(self):
        layout = QVBoxLayout(self)

        # Add a button to transition to a specific state
        self.transition_button = QPushButton("Go to Simulation State")
        self.transition_button.clicked.connect(self.go_to_simulation_state)
        layout.addWidget(self.transition_button)

        # Status label
        self.status_label = QLabel("Ready to send custom data")
        layout.addWidget(self.status_label)

    def go_to_simulation_state(self):
        """Transition to the Simulation state."""
        try:
            message = self.state_machine_manager.transition_to_state("Simulation")
            self.status_label.setText(message)
        except Exception as e:
            self.status_label.setText(f"Error: {e}")

class SerialReaderTab(QWidget):
    """Tab for high-speed serial reading"""
    def __init__(self, connection_manager, state_machine_manager, parent=None):
        super().__init__(parent)
        self.connection_manager = connection_manager
        self.state_machine_manager = state_machine_manager
        self.serial_reader = None
        self.setup_ui()

    def setup_ui(self):
        """Set up the UI for the serial reader tab"""
        layout = QVBoxLayout(self)

        # File selection
        file_layout = QHBoxLayout()
        self.file_path_edit = QLineEdit()
        self.file_path_edit.setPlaceholderText("Select output file...")
        self.browse_button = QPushButton("Browse")
        self.browse_button.clicked.connect(self.select_output_file)
        file_layout.addWidget(self.file_path_edit)
        file_layout.addWidget(self.browse_button)
        layout.addLayout(file_layout)

        # Duration input
        duration_layout = QHBoxLayout()
        self.duration_edit = QLineEdit()
        self.duration_edit.setPlaceholderText("Enter duration (seconds, optional)")
        duration_layout.addWidget(QLabel("Duration:"))
        duration_layout.addWidget(self.duration_edit)
        layout.addLayout(duration_layout)

        # Serial reader controls
        control_layout = QHBoxLayout()
        self.start_reader_button = QPushButton("Start Reading")
        self.start_reader_button.clicked.connect(self.start_serial_reader)
        self.stop_reader_button = QPushButton("Stop Reading")
        self.stop_reader_button.clicked.connect(self.stop_serial_reader)
        self.stop_reader_button.setEnabled(False)
        control_layout.addWidget(self.start_reader_button)
        control_layout.addWidget(self.stop_reader_button)
        layout.addLayout(control_layout)

        # Status display
        self.reader_status_label = QLabel("Ready")
        layout.addWidget(self.reader_status_label)

        # Console output
        self.reader_console = QTextEdit()
        self.reader_console.setReadOnly(True)
        layout.addWidget(self.reader_console)

    def select_output_file(self):
        """Open a file dialog to select the save location."""
        options = QFileDialog.Option.DontUseNativeDialog
        file_name, _ = QFileDialog.getSaveFileName(
            self,
            "Select Output File",
            "",
            "Text Files (*.txt);;All Files (*)",
            options=options
        )
        if file_name:
            self.file_path_edit.setText(file_name)

    def start_serial_reader(self):
        """Start the high-speed serial reader."""
        if self.serial_reader and self.serial_reader.isRunning():
            QMessageBox.warning(self, "Warning", "Reader is already running")
            return

        if not self.connection_manager.serial_connection:
            QMessageBox.warning(self, "Warning", "Not connected to a serial port")
            return

        output_file = self.file_path_edit.text()
        if not output_file:
            QMessageBox.warning(self, "Warning", "Please select an output file")
            return

        try:
            duration = float(self.duration_edit.text()) if self.duration_edit.text() else None
        except ValueError:
            QMessageBox.warning(self, "Warning", "Invalid duration value")
            return

        self.reader_console.clear()
        self.reader_status_label.setText("Starting serial reader...")

        # Use the existing serial connection from the connection manager
        self.serial_reader = fpga.SerialReaderThread(
            serial_connection=self.connection_manager.serial_connection,
            output_file=output_file,
            read_time=duration
        )

        self.serial_reader.update_signal.connect(self.update_reader_status)
        self.serial_reader.finished_signal.connect(self.reader_finished)
        self.serial_reader.start()

        self.start_reader_button.setEnabled(False)
        self.stop_reader_button.setEnabled(True)
    def stop_serial_reader(self):
        """Stop the high-speed serial reader."""
        if self.serial_reader and self.serial_reader.isRunning():
            self.serial_reader.stop()
            self.reader_status_label.setText("Stopping reader...")
            self.stop_reader_button.setEnabled(False)

    def update_reader_status(self, message):
        """Update the console with messages from the serial reader."""
        self.reader_console.append(message)

    def reader_finished(self, bytes_read):
        """Handle the completion of the serial reader."""
        self.reader_status_label.setText(f"Reader finished. {bytes_read} bytes read")
        self.start_reader_button.setEnabled(True)
        self.stop_reader_button.setEnabled(False)
        self.serial_reader = None

class MainWindow(QMainWindow):
    """Main application window."""
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Digital Twin Interface")
        self.resize(800, 600)

        # Create the main tab widget
        self.tab_widget = QTabWidget()
        self.setCentralWidget(self.tab_widget)

        # Create the shared SerialConnectionManager instance
        self.connection_manager = SerialConnectionManager(None, None, None, None)

        # Add the connection tab first
        self.connection_tab = ConnectionTab(self.connection_manager)
        self.tab_widget.addTab(self.connection_tab, "Connection")
        
        # Get the state machine manager from the connection tab
        self.state_machine_manager = self.connection_tab.get_state_machine_manager()

        # Add other tabs and pass the state machine manager
        self.custom_signal_tab = CustomSignalTab(self.connection_manager, self.state_machine_manager)
        self.tab_widget.addTab(self.custom_signal_tab, "Custom Signals")
        self.predefined_signal_tab = pre_def.PredefinedSignalTab(self.connection_manager, self.state_machine_manager)
        self.tab_widget.addTab(self.predefined_signal_tab, "Predefined Signals")

        self.serial_reader_tab = SerialReaderTab(self.connection_manager, self.state_machine_manager)


def main():
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())

if __name__ == "__main__": 
    main()