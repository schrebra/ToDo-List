
# Modern Windows ToDo List Application

A sleek, Windows 11-inspired task management application built with PowerShell and Windows Forms.

![image](https://github.com/user-attachments/assets/473e9d36-68db-428a-83e0-e7b5f4a81b3a)

## Features

- 🎨 Modern, Windows 11-inspired user interface
- 📝 Multiple todo lists support
- 🔄 Undo/redo functionality for both tasks and lists
- 📌 Set default lists for quick access
- ✏️ Edit existing tasks
- ⏰ Automatic timestamp tracking for task creation and completion
- 🔍 Sortable columns for better organization
- 💾 Automatic saving of tasks and application settings
- ✅ Visual task completion with strikethrough effect
- 📱 Responsive design that adapts to window resizing

## Why This Application?

### 1. Native Windows Integration
Unlike web-based alternatives, this application is built specifically for Windows, providing a seamless, native experience that matches the modern Windows 11 aesthetic.

### 2. Lightweight and Fast
Built with PowerShell and Windows Forms, the application is extremely lightweight and starts instantly, using minimal system resources compared to Electron-based alternatives.

### 3. Privacy-Focused
All data is stored locally on your machine - no cloud storage, no data collection, and no internet connection required. Your tasks remain completely private.

### 4. Multiple List Management
Perfect for users who need to separate tasks into different contexts (work, personal, projects, etc.) while maintaining a clean, organized interface.

### 5. Persistent Settings
The application remembers your preferences, window size, column widths, and default list, providing a consistent experience across sessions.

### 6. Business-Friendly
Ideal for business environments where cloud-based solutions might be restricted, or when dealing with sensitive information that needs to remain local.

## Installation

1. Download the `todo.ps1` script
2. Right-click the script and select "Run with PowerShell"
3. For easier access, create a shortcut to the script on your desktop

## Requirements

- Windows 7/8/10/11
- PowerShell 5.1 or later
- .NET Framework 4.5 or later

## Usage

- Create multiple lists for different contexts (Work, Personal, Shopping, etc.)
- Add, edit, and remove tasks with simple clicks
- Mark tasks as complete with checkboxes
- Sort tasks by completion status, description, or dates
- Undo accidental deletions of both tasks and lists
- Set frequently used lists as default

## Storage

Tasks and settings are stored in your Documents folder under a `TodoListApp` directory:
- Tasks are saved as JSON files (one per list)
- Settings are saved in an INI file

## Contributing

Feel free to fork this repository and submit pull requests for any improvements you'd like to add. Please ensure your code matches the existing style and includes appropriate comments.

## License

MIT License - feel free to use this code in your own projects, commercial or otherwise.
