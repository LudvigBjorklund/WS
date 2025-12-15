
import sys
import time
import serial
from PyQt6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                            QHBoxLayout, QPushButton, QLabel, QComboBox, 
                            QGroupBox, QLineEdit, QMessageBox, QTabWidget)
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
        self.serial_connection = None
        self.current_state = None

        # Define state values (using binary strings for transitions)
        self.state_ID = '0' * 7 + '1'
        self.states = {
            'Idle': self.state_ID + '0' * 24,          # Idle state
            'Initialization': self.state_ID + '0' * 23 + '1',       # Init state
            'Verification': self.state_ID + '0' * 22 + '10', # Verification state
            'Simulation': self.state_ID + '0' * 22 + '11', # Simulation state
            'Pause': self.state_ID + '0' * 21 + '100' # Pause state
        }
        
        # Define signal parameters in a nested dictionary
        self.parameter_dict = {
            'I': {'ID': 2, 'Format_String': '5EN11', 'Default_Value': 5, 'Description': 'Current'},
            'SOC': {'ID': 4, 'Format_String': '7EN9', 'Default_Value': 75, 'Description': 'State of Charge (%)'},
            'R0' : {'ID': 3, 'Format_String': '8EN8', 'Default_Value': 127, 'Description': 'Internal Resistance [mOhm]'},
        }

        self.initUI()

    def initUI(self):
        self.setWindowTitle('FPGA-based Digital Twin Communication Interface')
        self.setGeometry(100, 100, 800, 400)
        self.setMinimumSize(QSize(800, 400))

        main_widget = QWidget()
        main_layout = QVBoxLayout()
        main_widget.setLayout(main_layout)
        self.setCentralWidget(main_widget)

        # Serial connection setup
        connection_group = QGroupBox("Serial Connection")
        connection_layout = QHBoxLayout()

        self.port_combo = QComboBox()
        self.port_combo.addItems(["/dev/ttyUSB0", "/dev/ttyUSB1",  "/dev/ttyUSB2","COM1", "COM2", "COM3"])
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

        self.state_widgets = {}
        for state_name in ["Idle", "Initialization", "Verification", "Simulation", "Pause"]:
            # Create state circle widgets
            state_widget = StateCircle(state_name)
            self.state_widgets[state_name] = state_widget
            states_layout.addWidget(state_widget)

        states_group.setLayout(states_layout)
        main_layout.addWidget(states_group)

        # State transition buttons
        buttons_layout = QHBoxLayout()
        for state_name in ["Idle", "Initialization", "Verification", "Simulation","Pause"]:
            button = QPushButton(f"Go to {state_name}")
            button.clicked.connect(lambda checked, s=state_name: self.transition_to_state(s))
            buttons_layout.addWidget(button)
        main_layout.addLayout(buttons_layout)

        # Status bar for messages
        self.status_label = QLabel("Not connected")
        main_layout.addWidget(self.status_label)

        # Create tab widget for different signal sending methods
        tab_widget = QTabWidget()
        
        # Tab 1: Custom signal entry
        custom_tab = QWidget()
        custom_layout = QVBoxLayout()
        custom_tab.setLayout(custom_layout)
        
        # Preview buttons for custom signals
        preview_layout = QHBoxLayout()
        preview_button = QPushButton("Preview (Decimal)")
        preview_button.clicked.connect(self.preview_custom_data)
        preview_binary_button = QPushButton("Preview (Binary)")
        preview_binary_button.clicked.connect(self.preview_binary_data)
        preview_layout.addWidget(preview_button)
        preview_layout.addWidget(preview_binary_button)
        custom_layout.addLayout(preview_layout)

        # Custom data input section
        data_group = QGroupBox("Send Custom Data")
        data_layout = QHBoxLayout()

        self.id_input = QLineEdit()
        self.id_input.setPlaceholderText("Enter ID (decimal, will be '8EN0')")
        self.value_input = QLineEdit()
        self.value_input.setPlaceholderText("Enter Value (decimal)")

        self.value_fmt_input = QLineEdit()
        self.value_fmt_input.setPlaceholderText("Enter format for value (e.g., 24EN0)")

        self.send_button = QPushButton("Send Data")
        self.send_button.clicked.connect(self.send_custom_data)
        
        data_layout.addWidget(QLabel("ID:"))
        data_layout.addWidget(self.id_input)
        data_layout.addWidget(QLabel("Value:"))
        data_layout.addWidget(self.value_input)
        data_layout.addWidget(QLabel("Format:"))
        data_layout.addWidget(self.value_fmt_input)
        data_layout.addWidget(self.send_button)
        data_group.setLayout(data_layout)
        custom_layout.addWidget(data_group)
        
        # Tab 2: Predefined signals
        predefined_tab = QWidget()
        predefined_layout = QVBoxLayout()
        predefined_tab.setLayout(predefined_layout)
        
        # Signal selection dropdown
        signal_group = QGroupBox("Send Predefined Signal")
        signal_layout = QVBoxLayout()
        
        # Top row with dropdown and information fields
        signal_top_layout = QHBoxLayout()
        
        # Signal selection dropdown
        self.signal_dropdown = QComboBox()
        signal_names = list(self.parameter_dict.keys())
        self.signal_dropdown.addItems(signal_names)
        self.signal_dropdown.currentIndexChanged.connect(self.update_signal_info)
        
        signal_top_layout.addWidget(QLabel("Signal:"))
        signal_top_layout.addWidget(self.signal_dropdown)
        
        # Signal information fields (read-only)
        self.signal_id_display = QLineEdit()
        self.signal_id_display.setReadOnly(True)
        self.signal_format_display = QLineEdit()
        self.signal_format_display.setReadOnly(True)
        self.signal_description_display = QLineEdit()
        self.signal_description_display.setReadOnly(True)
        
        signal_top_layout.addWidget(QLabel("ID:"))
        signal_top_layout.addWidget(self.signal_id_display)
        signal_top_layout.addWidget(QLabel("Format:"))
        signal_top_layout.addWidget(self.signal_format_display)
        signal_top_layout.addWidget(QLabel("Description:"))
        signal_top_layout.addWidget(self.signal_description_display)
        
        signal_layout.addLayout(signal_top_layout)
        
        # Bottom row with value input and send button
        signal_bottom_layout = QHBoxLayout()
        
        self.signal_value_input = QLineEdit()
        self.signal_preview_button = QPushButton("Preview")
        self.signal_preview_button.clicked.connect(self.preview_predefined_signal)
        self.signal_send_button = QPushButton("Send Signal")
        self.signal_send_button.clicked.connect(self.send_predefined_signal)
        
        signal_bottom_layout.addWidget(QLabel("Value:"))
        signal_bottom_layout.addWidget(self.signal_value_input)
        signal_bottom_layout.addWidget(self.signal_preview_button)
        signal_bottom_layout.addWidget(self.signal_send_button)
        
        signal_layout.addLayout(signal_bottom_layout)
        signal_group.setLayout(signal_layout)
        predefined_layout.addWidget(signal_group)
        
        # Add tabs to tab widget
        tab_widget.addTab(custom_tab, "Custom Signal")
        tab_widget.addTab(predefined_tab, "Predefined Signals")
        
        main_layout.addWidget(tab_widget)
        
        # Initialize the signal info with the first signal
        self.update_signal_info(0)
        
        # Set default state
        self.transition_to_state("Idle", send_to_fpga=False)
        
    def update_signal_info(self, index):
        """Update the signal information fields based on the selected signal."""
        signal_name = self.signal_dropdown.currentText()
        if signal_name in self.parameter_dict:
            signal_info = self.parameter_dict[signal_name]
            self.signal_id_display.setText(str(signal_info['ID']))
            self.signal_format_display.setText(signal_info['Format_String'])
            self.signal_description_display.setText(signal_info['Description'])
            self.signal_value_input.setText(str(signal_info['Default_Value']))
        else:
            # Clear fields if signal not found
            self.signal_id_display.clear()
            self.signal_format_display.clear()
            self.signal_description_display.clear()
            self.signal_value_input.clear()

    def preview_predefined_signal(self):
        """Preview the currently selected predefined signal."""
        try:
            signal_name = self.signal_dropdown.currentText()
            signal_info = self.parameter_dict[signal_name]
            
            id_decimal = signal_info['ID']
            value_decimal = float(self.signal_value_input.text())
            format_string = signal_info['Format_String']
            
            # Process the signal data
            result = self.process_signal_data(id_decimal, value_decimal, format_string)
            
            # Show both decimal and binary previews
            preview_text = f"Signal: {signal_name} ({signal_info['Description']})\n"
            preview_text += f"Decimal value: {result['combined_data']}\n\n"
            preview_text += f"Binary representation:\n"
            preview_text += self.format_data_for_display(
                result['id_bin'], 
                result['value_bin'], 
                result['combined_bin']
            )
            
            if result['padding_bits'] > 0:
                preview_text += f"\n\nPadding bits: {result['padding_bits']} bits inserted between ID and value"
                
            QMessageBox.information(self, f"Preview: {signal_name}", preview_text)
        except Exception as e:
            QMessageBox.warning(self, "Error", f"Preview failed: {e}")
    
    def send_predefined_signal(self):
        """Send the currently selected predefined signal."""
        try:
            signal_name = self.signal_dropdown.currentText()
            signal_info = self.parameter_dict[signal_name]
            
            id_decimal = signal_info['ID']
            value_decimal = float(self.signal_value_input.text())
            format_string = signal_info['Format_String']
            
            # Process the signal data
            result = self.process_signal_data(id_decimal, value_decimal, format_string)
            
            # Send the combined data
            self.write_to_fpga(result['combined_data'])
            self.status_label.setText(f"Signal '{signal_name}' sent successfully.")
        except ValueError as e:
            self.status_label.setText(f"Error: {e}")
        except Exception as e:
            self.status_label.setText(f"Unexpected error: {e}")
    
    def process_signal_data(self, id_decimal, value_decimal, format_string):
        """Process signal data with the given ID, value and format string."""
        # Convert the ID using the fixed "8EN0" format
        id_bin = preprocess.decimal_to_binary_string(id_decimal, "8EN0")
        
        # Parse the format string to get total bits needed
        int_bits, frac_bits, is_negative = preprocess.format_parse_string(format_string)
        total_value_bits = int(int_bits) + int(frac_bits)
        
        
        # Convert the value using the provided format
        value_bin = preprocess.decimal_to_binary_string(value_decimal, format_string)
        
        # Calculate how many padding bits are needed between ID and value
        # The total packet should be 32 bits, with 8 bits for ID
        padding_bits = 24 - total_value_bits
        
        # Create the combined binary string with padding in between if needed
        if padding_bits > 0:
            combined_bin = id_bin + '0' * padding_bits + value_bin
        else:
            # If the value format is already using 24 bits or more
            combined_bin = id_bin + value_bin
        
        # Ensure the combined binary string is exactly 32 bits
        if len(combined_bin) < 32:
            combined_bin = combined_bin.rjust(32, '0')
        elif len(combined_bin) > 32:
            combined_bin = combined_bin[-32:]  # Keep the 32 LSBs
            
        # Convert combined binary string to integer
        combined_data = int(combined_bin, 2)
        
        return {
            'id_bin': id_bin,
            'value_bin': value_bin,
            'padding_bits': padding_bits,
            'combined_bin': combined_bin,
            'combined_data': combined_data
        }

    def format_data_for_display(self, id_bin, value_bin, total_bin):
        """Format the binary data with proper spacing for display."""
        return f"ID (8 bits): {id_bin}\nValue: {value_bin}\nCombined (32 bits): {total_bin[:8]} {total_bin[8:]}"

    def process_custom_data(self):
        """Process the custom data and return the components."""
        # Parse the decimal values from the UI fields
        id_decimal = float(self.id_input.text())
        value_decimal = float(self.value_input.text())

        # Get the format string from user input or use default
        fmt_str = self.value_fmt_input.text().strip() or "24EN0"
        
        # Use the common processing function
        return self.process_signal_data(id_decimal, value_decimal, fmt_str)

    def preview_binary_data(self):
        """Preview the data in binary format with spacing between ID and value."""
        try:
            result = self.process_custom_data()
            
            # Format the binary data with spacing for display
            binary_display = self.format_data_for_display(
                result['id_bin'], 
                result['value_bin'], 
                result['combined_bin']
            )
            
            if result['padding_bits'] > 0:
                padding_info = f"\nPadding bits: {result['padding_bits']} bits inserted between ID and value"
                binary_display += padding_info
                
            QMessageBox.information(self, "Binary Preview", binary_display)
        except Exception as e:
            QMessageBox.warning(self, "Error", f"Binary conversion failed: {e}")

    def preview_custom_data(self):
        try:
            result = self.process_custom_data()
            QMessageBox.information(self, "Converted Value",
                                    f"Converted value (integer): {result['combined_data']}")
        except Exception as e:
            QMessageBox.warning(self, "Error", f"Conversion failed: {e}")
            
    def send_custom_data(self):
        try:
            result = self.process_custom_data()
            # Send the data to the FPGA
            self.write_to_fpga(result['combined_data'])
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
            self.status_label.setText(f"Error: {e}")

    def disconnect_serial(self):
        if self.serial_connection:
            self.serial_connection.close()
            self.serial_connection = None
        self.status_label.setText("Disconnected")
        self.connect_button.setText("Connect")
        self.connect_button.clicked.disconnect()
        self.connect_button.clicked.connect(self.connect_serial)

    def transition_to_state(self, state_name, send_to_fpga=True):
        # Update UI states
        for name, widget in self.state_widgets.items():
            widget.setActive(name == state_name)
        self.current_state = state_name
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
                time.sleep(0.1)  # Add a small delay (100ms) to ensure the buffer is processed

            except Exception as e:
                self.status_label.setText(f"Error writing to serial port: {e}")

def main():
    app = QApplication(sys.argv)
    window = StateMachineGUI()
    window.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()