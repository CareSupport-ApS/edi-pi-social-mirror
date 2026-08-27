import tkinter as tk
import time
import os
import threading
import sys

PROGRESS_FILE = "/tmp/ansible_progress"

class ProgressBarApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Social Mirror Installation")
        self.root.attributes('-fullscreen', True)
        self.root.configure(bg='black')
        
        # Center frame
        self.frame = tk.Frame(root, bg='black')
        self.frame.place(relx=0.5, rely=0.5, anchor='center')
        
        # Title
        self.label_title = tk.Label(
            self.frame, 
            text="Social Mirror Installation", 
            font=("Helvetica", 32, "bold"), 
            fg="white", 
            bg="black"
        )
        self.label_title.pack(pady=20)
        
        # Status text
        self.label_status = tk.Label(
            self.frame, 
            text="Initializing...", 
            font=("Helvetica", 18), 
            fg="#cccccc", 
            bg="black"
        )
        self.label_status.pack(pady=10)
        
        # Progress bar (simulated with a canvas)
        self.canvas_width = 600
        self.canvas_height = 30
        self.canvas = tk.Canvas(
            self.frame, 
            width=self.canvas_width, 
            height=self.canvas_height, 
            bg="#333333", 
            highlightthickness=0
        )
        self.canvas.pack(pady=20)
        
        self.progress_rect = self.canvas.create_rectangle(0, 0, 0, self.canvas_height, fill="#00ff00", width=0)
        
        # Start checking for updates
        self.check_updates()

    def check_updates(self):
        if os.path.exists(PROGRESS_FILE):
            try:
                with open(PROGRESS_FILE, 'r') as f:
                    content = f.read().strip()
                    if content:
                        parts = content.split('|')
                        if len(parts) >= 2:
                            percent = float(parts[0])
                            message = parts[1]
                            self.update_progress(percent, message)
            except Exception as e:
                print(f"Error reading progress: {e}")
        
        self.root.after(1000, self.check_updates)

    def update_progress(self, percent, message):
        # Clamp percent between 0 and 100
        percent = max(0, min(100, percent))
        
        # Update width
        new_width = (percent / 100) * self.canvas_width
        self.canvas.coords(self.progress_rect, 0, 0, new_width, self.canvas_height)
        
        # Update text
        self.label_status.config(text=f"{message} ({int(percent)}%)")

if __name__ == "__main__":
    # Create the progress file if it doesn't exist
    if not os.path.exists(PROGRESS_FILE):
        with open(PROGRESS_FILE, 'w') as f:
            f.write("0|Starting installation...")

    root = tk.Tk()
    # Hide cursor
    root.config(cursor="none")
    app = ProgressBarApp(root)
    root.mainloop()
