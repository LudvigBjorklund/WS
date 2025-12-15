import sys
import serial
from PyQt6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                            QHBoxLayout, QPushButton, QLabel, QComboBox, 
                            QGroupBox, QLineEdit)
from PyQt6.QtGui import QPainter, QBrush, QPen, QColor
from PyQt6.QtCore import Qt, QSize
import os
# Add preprocessing functions from the module in the parent directory
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import Preprocessing as preprocess


class StateCircle(QWidget):
    def __init__(self, state_name):
        super().__init__()
        self.state_name = state_name
        self.active = False
        self.setMinimumSize(100, 100)
        
    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        # Draw circle
        painter.setPen(QPen(Qt.GlobalColor.black, 2))
        if self.active:
            painter.setBrush(QBrush(QColor(0, 200, 0)))  # Green for active state
        else:
            painter.setBrush(QBrush(QColor(200, 200, 200)))  # Gray for inactive state

        circle_radius = int(min(self.width(), self.height()) * 0.4)
        center_x = int(self.width() / 2)
        center_y = int(self.height() / 2)
        painter.drawEllipse(center_x - circle_radius, center_y - circle_radius, 
                            circle_radius * 2, circle_radius * 2)

        # Draw state name
        painter.setPen(Qt.GlobalColor.black)
        painter.drawText(self.rect(), Qt.AlignmentFlag.AlignCenter, self.state_name)
            
    def setActive(self, active):
        self.active = active
        self.update()  # Trigger repaint


class StateMachineGUI(QMainWindow):
    def __init__(self):
        super().__init__()
        self.initUI()
        self.serial_connection = None
        self.current_state = None

        # Define state values
        self.state_ID = '0' * 7 + '1'
        self.states = {
            'Idle': self.state_ID + '0' * 24,  # Idle state
            'Init': self.state_ID + '0' * 23 + '1',  # Init state
            'Verification': self.state_ID + '0' * 22 + '10',  # Verification state
            'Simulation': self.state_ID + '0' * 22 + '11'  # Simulation state
        }

    def initUI(self):
        self.setWindowTitle('FPGA State Machine Controller')
        self.setGeometry(100, 100, 800, 400)

        main_widget = QWidget()
        main_layout = QVBoxLayout()
        main_widget.setLayout(main_layout)
        self.setCentralWidget(main_widget)

        # Serial connection setup
        connection_group = QGroupBox("Serial Connection")
        connection_layout = QHBoxLayout()

        self.port_combo = QComboBox()
        self.port_combo.addItems(["/dev/ttyUSB0", "/dev/ttyUSB1", "COM1", "COM2", "COM3"])
        self.port_combo.setEditable(True)

        self.baudrate_combo = QComboBox()
        self.baudrate_combo.addItems(["9600", "19200", "38400", "57600", "115200"])
        self.baudrate_combo.setCurrentText("115200")

        self.connect_button = QPushButton("Connect")
        self.connect_button.clicked.connect(self.connect_serial)

        connection_layout.addWidget(QLabel("Port:"))
        connection_layout.addWidget(self.port_combo)
        connection_layout.addWidget(QLabel("Baudrate:"))
        connection_layout.addWidget(self.baudrate_combo)
        connection_layout.addWidget(self.connect_button)
        connection_group.setLayout(connection_layout)

        main_layout.addWidget(connection_group)

        # State visualization
        states_group = QGroupBox("State Machine")
        states_layout = QHBoxLayout()

        # Create state circles
        self.state_widgets = {}
        for state_name in ["Idle", "Init", "Verification", "Simulation"]:
            state_widget = StateCircle(state_name)
            self.state_widgets[state_name] = state_widget
            states_layout.addWidget(state_widget)

        states_group.setLayout(states_layout)
        main_layout.addWidget(states_group)

        # State transition buttons
        buttons_layout = QHBoxLayout()

        for state_name in ["Idle", "Init", "Verification", "Simulation"]:
            button = QPushButton(f"Transition to {state_name}")
            button.clicked.connect(lambda checked, s=state_name: self.transition_to_state(s))
            buttons_layout.addWidget(button)

        main_layout.addLayout(buttons_layout)

        # Status bar for messages
        self.status_label = QLabel("Not connected")
        main_layout.addWidget(self.status_label)

        # Add custom data input section
        data_group = QGroupBox("Send Custom Data")
        data_layout = QHBoxLayout()

        self.id_input = QLineEdit()
        self.id_input.setPlaceholderText("Enter 8-bit ID (0-255)")
        self.value_input = QLineEdit()
        self.value_input.setPlaceholderText("Enter 24-bit Value (0-16777215)")

        self.send_button = QPushButton("Send Data")
        self.send_button.clicked.connect(self.send_custom_data)

        data_layout.addWidget(QLabel("ID:"))
        data_layout.addWidget(self.id_input)
        data_layout.addWidget(QLabel("Value:"))
        data_layout.addWidget(self.value_input)
        data_layout.addWidget(self.send_button)
        data_group.setLayout(data_layout)

        main_layout.addWidget(data_group)

        # Set default state
        self.transition_to_state("Idle", send_to_fpga=False)

    def send_custom_data(self):
        try:
            # Parse ID and Value
            id_value = int(self.id_input.text())
            data_value = int(self.value_input.text())

            # Validate input ranges
            if not (0 <= id_value <= 255):
                raise ValueError("ID must be an 8-bit value (0-255).")
            if not (0 <= data_value <= 16777215):
                raise ValueError("Value must be a 24-bit value (0-16777215).")

            # Combine ID and Value into a 32-bit integer
            combined_data = (id_value << 24) | data_value

            # Send data to FPGA
            self.write_to_fpga(combined_data)
            self.status_label.setText("Data sent successfully.")
        except ValueError as e:
            self.status_label.setText(f"Error: {e}")
        except Exception as e:
            self.status_label.setText(f"Unexpected error: {e}")

    def connect_serial(self):
        port = self.port_combo.currentText()
        baudrate = int(self.baudrate_combo.currentText())

        try:
            self.serial_connection = serial.Serial(port, baudrate)
            self.status_label.setText(f"Connected to {port} at {baudrate} baud")
            self.connect_button.setText("Disconnect")
            self.connect_button.clicked.disconnect()
            self.connect_button.clicked.connect(self.disconnect_serial)
        except serial.SerialException as e:
            self.status_label.setText(f"Error: {str(e)}")

    def disconnect_serial(self):
        if self.serial_connection:
            self.serial_connection.close()
            self.serial_connection = None

        self.status_label.setText("Disconnected")
        self.connect_button.setText("Connect")
        self.connect_button.clicked.disconnect()
        self.connect_button.clicked.connect(self.connect_serial)

    def transition_to_state(self, state_name, send_to_fpga=True):
        # Update UI
        for name, widget in self.state_widgets.items():
            widget.setActive(name == state_name)

        self.current_state = state_name

        # Send to FPGA if connected
        if send_to_fpga and self.serial_connection:
            state_value = self.states[state_name]
            binary_value = int(state_value, 2)
            self.write_to_fpga(binary_value)
            self.status_label.setText(f"Transitioned to {state_name} state")
        elif not send_to_fpga:
            self.status_label.setText(f"UI initialized with {state_name} state")
        else:
            self.status_label.setText(f"Not connected: Can't send {state_name} state to FPGA")

    def write_to_fpga(self, data):
        if self.serial_connection:
            try:
                # Convert the integer to 4 bytes (32 bits)
                data_bytes = data.to_bytes(4, byteorder='big')
                self.serial_connection.write(data_bytes)
                self.serial_connection.flush()  # Ensure all data is sent
            except Exception as e:
                self.status_label.setText(f"Error writing to serial port: {e}")


def main():
    app = QApplication(sys.argv)
    window = StateMachineGUI()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
    # Example usage
    port = "/dev/ttyUSB1"  
    baudrate = 115200
    state_ID = 7*'0'+'1'
    s_idle = state_ID + '0'*24 # Idle state
    s_init = state_ID + '0'*23+'1' # Init state
    s_verification = state_ID + '0'*22+'10' # Verification state
    s_simulation = state_ID + '0'*22+'11' # Simulation state
    
