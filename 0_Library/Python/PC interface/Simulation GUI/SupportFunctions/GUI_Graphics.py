from PyQt6.QtWidgets import QWidget
from PyQt6.QtGui import QPainter, QBrush, QPen, QColor
from PyQt6.QtCore import Qt

class StateCircle(QWidget):
    """Widget to visualize state machine states as circles"""
    def __init__(self, state_name):
        super().__init__()
        self.state_name = state_name
        self.active = False
        self.setMinimumSize(100, 100)

    def paintEvent(self, event):
        # Use a QPainter within a context manager to ensure proper cleanup
        painter = QPainter(self)
        try:
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
        finally:
            painter.end()  # Ensure the painter is properly ended

    def setActive(self, active):
        self.active = active
        self.update()  # Trigger repaint