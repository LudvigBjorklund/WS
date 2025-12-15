import sys
import os
from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QGroupBox, QLabel, QLineEdit, QComboBox, QPushButton, QMessageBox
sys.path.append( os.path.abspath(os.path.join(os.path.dirname(__file__), '..','..')))

import Preprocessing as preprocess
# class PredefinedSignalTab(QWidget):
#     """Tab for sending predefined signals"""
#     def __init__(self, connection_manager, parent=None):
#         super().__init__(parent)
#         self.connection_manager = connection_manager
        
#         # Define signal parameters in a nested dictionary
#         self.parameter_dict = {
#             'I'  : {'Class':'Parameter','ID': 2, 'Format_String': '5EN11', 'Default_Value': 5, 'Description': 'Current'},
#             'SOC': {'Class':'Parameter','ID': 3, 'Format_String': '7EN9', 'Default_Value': 75, 'Description': 'State of Charge (%)'},
#             'R0' : {'Class':'2DLUT' ,'ID': 4, 'Format_String': '8EN8', 'Default_Value': 127, 'Description': 'Overwrite Internal Resistance [mOhm]'},
#             'a1' : {'Class':'2DLUT' ,'ID': 5, 'Format_String': '-5EN11', 'Default_Value':0.00315581854, 'Description': 'Overwrite the inverted Resistance* Capacitance [Ohm*s]'},
#             'c1' : {'Class':'2DLUT' ,'ID': 6, 'Format_String': '0EN16', 'Default_Value': 0.003596475454, 'Description': 'Overwrite Capacitance [F]'}
#         }
        
#         self.setup_ui()
class PredefinedSignalTab(QWidget):
    """Tab for sending predefined signals."""
    def __init__(self, connection_manager, state_machine_manager, parent=None):
        super().__init__(parent)
        self.connection_manager = connection_manager
        self.state_machine_manager = state_machine_manager
        
        # Define signal parameters in a nested dictionary
        self.parameter_dict = {
            'I'  : {'Class':'Parameter','ID': 2, 'Format_String': '5EN11', 'Default_Value': 5, 'Description': 'Current'},
            'SOC': {'Class':'Parameter','ID': 3, 'Format_String': '7EN17', 'Default_Value': 75, 'Description': 'State of Charge initial(%)'},
            'R0' : {'Class':'2DLUT' ,'ID': 4, 'Format_String': '8EN8', 'Default_Value': 127, 'Description': 'Overwrite Internal Resistance [mOhm]'},
            'a1' : {'Class':'2DLUT' ,'ID': 5, 'Format_String': '-5EN11', 'Default_Value':0.00315581854, 'Description': 'Overwrite the inverted Resistance* Capacitance [Ohm*s]'},
            'c1' : {'Class':'2DLUT' ,'ID': 6, 'Format_String': '0EN16', 'Default_Value': 0.003596475454, 'Description': 'Overwrite Capacitance [F]'}
        }
        
        self.setup_ui()
    def setup_ui(self):
        layout = QVBoxLayout(self)
        
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
        layout.addWidget(signal_group)
        
        # Status label
        self.status_label = QLabel("Ready to send predefined signals")
        layout.addWidget(self.status_label)
        
        # Initialize the signal info with the first signal
        self.update_signal_info(0)
    
    def update_signal_info(self, index):
        """Update the signal information fields based on the selected signal"""
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
    
    def process_signal_data(self, id_decimal, value_decimal, format_string):
        """Process signal data with the given ID, value and format string"""
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
        """Format the binary data with proper spacing for display"""
        return f"ID (8 bits): {id_bin}\nValue: {value_bin}\nCombined (32 bits): {total_bin[:8]} \n {total_bin[8:16]} \n {total_bin[16:24]} \n{total_bin[24:]}\n" \

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
            
            # Send the combined data using the connection manager
            if self.connection_manager.write_to_fpga(result['combined_data']):
                self.status_label.setText(f"Signal '{signal_name}' sent successfully.")
            else:
                self.status_label.setText(f"Failed to send signal '{signal_name}'. Check connection.")
        except Exception as e:
            self.status_label.setText(f"Error: {e}")