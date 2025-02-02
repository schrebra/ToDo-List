# Modern To-Do List Application with Windows 11-inspired UI

# Module 1: Import Required Assemblies and Define Color Scheme
Add-Type -AssemblyName System.Windows.Forms, System.Drawing, System.Web.Extensions

$colors = @{
    Background = [System.Drawing.Color]::FromArgb(251, 251, 253)
    ButtonBackground = [System.Drawing.Color]::FromArgb(243, 243, 243)
    AccentBlue = [System.Drawing.Color]::FromArgb(0, 120, 212)
    TextPrimary = [System.Drawing.Color]::FromArgb(32, 32, 32)
    ListViewBackground = [System.Drawing.Color]::White
    CompletedTask = [System.Drawing.Color]::FromArgb(128, 128, 128)
    PlaceholderText = [System.Drawing.Color]::FromArgb(169, 169, 169)
    MenuBackground = [System.Drawing.Color]::White
    MenuHover = [System.Drawing.Color]::FromArgb(242, 242, 242)
}

# Module 2: Define Custom UI Classes
Add-Type -TypeDefinition @"
using System;
using System.Windows.Forms;
using System.Drawing;

public class ModernButton : Button {
    public ModernButton() : base() {
        FlatStyle = FlatStyle.Flat;
        FlatAppearance.BorderSize = 1;
        BackColor = Color.FromArgb(243, 243, 243);
        ForeColor = Color.FromArgb(32, 32, 32);
        FlatAppearance.BorderColor = Color.FromArgb(225, 225, 225);
        Font = new Font("Segoe UI", 11F, FontStyle.Regular);
        Cursor = Cursors.Hand;
    }
}

public class PlaceholderTextBox : TextBox {
    private string _placeholder = "";
    private Color _placeholderColor = Color.Gray;

    public string Placeholder {
        get { return _placeholder; }
        set { _placeholder = value; Invalidate(); }
    }

    public Color PlaceholderColor {
        get { return _placeholderColor; }
        set { _placeholderColor = value; Invalidate(); }
    }

    protected override void WndProc(ref Message m) {
        base.WndProc(ref m);
        if (m.Msg == 0xf && !Focused && string.IsNullOrEmpty(Text) && !string.IsNullOrEmpty(Placeholder)) {
            using (var g = CreateGraphics()) {
                TextRenderer.DrawText(g, Placeholder, Font, ClientRectangle, PlaceholderColor, BackColor, TextFormatFlags.VerticalCenter);
            }
        }
    }

    protected override void OnGotFocus(EventArgs e) { base.OnGotFocus(e); Invalidate(); }
    protected override void OnLostFocus(EventArgs e) { base.OnLostFocus(e); Invalidate(); }
}
"@ -ReferencedAssemblies System.Windows.Forms, System.Drawing

# Module 3: Set Up File Paths and Global Variables
$scriptPath = if ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    [System.IO.Path]::GetDirectoryName([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
}

$todoFolderPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "TodoListApp"
$settingsFilePath = Join-Path $todoFolderPath "settings.ini"

if (-not (Test-Path $todoFolderPath)) { 
    New-Item -ItemType Directory -Path $todoFolderPath -Force | Out-Null 
}

$script:deletedItems = @()
$script:undoItemButton = $script:undoListButton = $null
$script:lastDeletedList = $null
$script:currentSortColumn = 2
$script:currentSortOrder = "Ascending"

# Module 4: Helper Functions
function Load-Settings {
    if (Test-Path $settingsFilePath) {
        $settings = Get-Content $settingsFilePath | ConvertFrom-StringData
        return @{
            DefaultList = $settings.DefaultList
            WindowWidth = [int]$settings.WindowWidth
            WindowHeight = [int]$settings.WindowHeight
            Column1Width = [int]$settings.Column1Width
            Column2Width = [int]$settings.Column2Width
            Column3Width = [int]$settings.Column3Width
            Column4Width = [int]$settings.Column4Width
            SortColumn = [int]$settings.SortColumn
            SortOrder = $settings.SortOrder
        }
    }
    return @{
        DefaultList = ""; WindowWidth = 1037; WindowHeight = 507;
        Column1Width = 30; Column2Width = 519; Column3Width = 160; Column4Width = 160;
        SortColumn = 2; SortOrder = "Ascending"
    }
}

function Save-Settings {
    @(
        "DefaultList=$script:defaultList",
        "WindowWidth=$($form.Width)",
        "WindowHeight=$($form.Height)",
        "Column1Width=$($listView.Columns[0].Width)",
        "Column2Width=$($listView.Columns[1].Width)",
        "Column3Width=$($listView.Columns[2].Width)",
        "Column4Width=$($listView.Columns[3].Width)",
        "SortColumn=$script:currentSortColumn",
        "SortOrder=$script:currentSortOrder"
    ) | Out-File $settingsFilePath -Encoding UTF8
}

function Load-Tasks($listName) {
    $todoFilePath = Join-Path $todoFolderPath "$listName.json"
    if (Test-Path $todoFilePath) {
        $json = Get-Content $todoFilePath -Raw
        return (New-Object System.Web.Script.Serialization.JavaScriptSerializer).DeserializeObject($json)
    }
    return @()
}

function Save-Tasks($listName) {
    $tasks = $listView.Items | ForEach-Object {
        @{
            Text = $_.SubItems[1].Text
            DateEntered = $_.SubItems[2].Text
            DateCompleted = $_.SubItems[3].Text
            Completed = $_.Checked
        }
    }
    $json = (New-Object System.Web.Script.Serialization.JavaScriptSerializer).Serialize($tasks)
    $todoFilePath = Join-Path $todoFolderPath "$listName.json"
    $json | Out-File $todoFilePath -Encoding UTF8
}

# Module 5: Task Management Functions
function Add-Task {
    if ($textBox.Text -ne "") {
        $item = New-Object System.Windows.Forms.ListViewItem("")
        $item.SubItems.Add($textBox.Text)
        $item.SubItems.Add((Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
        $item.SubItems.Add("")
        $item.UseItemStyleForSubItems = $false
        $item.BackColor = $colors.ListViewBackground
        $item.ForeColor = $colors.TextPrimary
        $listView.Items.Add($item)
        $textBox.Clear()
        Save-Tasks $script:currentList
        Sort-ListView
    }
}

function Edit-Task {
    if ($listView.SelectedItems.Count -eq 1) {
        $selectedItem = $listView.SelectedItems[0]
        $currentText = $selectedItem.SubItems[1].Text
        $newText = Show-InputBox "Edit Task" "Edit task text:" $currentText
        if ($newText -ne $null -and $newText -ne "") {
            $selectedItem.SubItems[1].Text = $newText
            Save-Tasks $script:currentList
            Sort-ListView
        }
    }
}

function Remove-SelectedTasks {
    if ($listView.SelectedItems.Count -gt 0) {
        $script:deletedItems = $listView.SelectedItems | ForEach-Object { $_.Clone() }
        $listView.SelectedItems | ForEach-Object { $listView.Items.Remove($_) }
        Save-Tasks $script:currentList
        $script:undoItemButton.Visible = $true
    }
}

function Undo-DeletedItem {
    $script:deletedItems | ForEach-Object { $listView.Items.Add($_) }
    $script:deletedItems = @()
    Save-Tasks $script:currentList
    Sort-ListView
    $script:undoItemButton.Visible = $false
}

# Module 6: List Management Functions
function Load-ListNames {
    Get-ChildItem -Path $todoFolderPath -Filter "*.json" | 
        Where-Object { -not $_.BaseName.StartsWith("deleted...") } | 
        ForEach-Object { $_.BaseName }
}

function New-TodoList {
    $newListName = Show-InputBox "New List" "Enter new list name:"
    if ($newListName -ne $null -and $newListName -ne "") {
        $comboBox.Items.Add($newListName)
        $comboBox.SelectedItem = $newListName
        Set-ControlsState $true
    }
    elseif ($comboBox.Items.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("You must create a list to continue.", "No Lists Available", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        New-TodoList
    }
}

function Remove-TodoList {
    if ($script:currentList -ne $null) {
        $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to delete the list '$script:currentList'?", "Confirm Delete", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            $todoFilePath = Join-Path $todoFolderPath "$script:currentList.json"
            $deletedFilePath = Join-Path $todoFolderPath "deleted...$script:currentList.json"
            if (Test-Path $todoFilePath) { Rename-Item -Path $todoFilePath -NewName $deletedFilePath }
            $comboBox.Items.Remove($script:currentList)
            if ($script:currentList -eq $script:defaultList) { $script:defaultList = $null }
            $script:lastDeletedList = $script:currentList
            if ($comboBox.Items.Count -gt 0) { $comboBox.SelectedIndex = 0 }
            else {
                $script:currentList = $null
                $listView.Items.Clear()
                Set-ControlsState $false
                New-TodoList
            }
            Save-Settings
            $script:undoListButton.Visible = $true
        }
    }
}

function Undo-DeletedList {
    if ($script:lastDeletedList -ne $null) {
        $deletedFilePath = Join-Path $todoFolderPath "deleted...$script:lastDeletedList.json"
        $restoredFilePath = Join-Path $todoFolderPath "$script:lastDeletedList.json"
        if (Test-Path $deletedFilePath) {
            Rename-Item -Path $deletedFilePath -NewName $restoredFilePath
            $comboBox.Items.Add($script:lastDeletedList)
            $comboBox.SelectedItem = $script:lastDeletedList
        }
        $script:lastDeletedList = $null
        $script:undoListButton.Visible = $false
    }
}

function Set-DefaultList {
    $script:defaultList = $script:currentList
    [System.Windows.Forms.MessageBox]::Show("'$script:defaultList' has been set as the default list.", "Default List Set", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    Save-Settings
}

# Module 7: UI Helper Functions
function Show-InputBox($title, $prompt, $defaultValue = "") {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $title
    $form.Size = New-Object System.Drawing.Size(400,200)
    $form.StartPosition = "CenterScreen"
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $form.BackColor = $colors.Background
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox = $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,20)
    $label.Size = New-Object System.Drawing.Size(380,30)
    $label.Text = $prompt
    $label.ForeColor = $colors.TextPrimary
    $form.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(10,60)
    $textBox.Size = New-Object System.Drawing.Size(360,30)
    $textBox.Text = $defaultValue
    $textBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $textBox.BackColor = $colors.ListViewBackground
    $textBox.ForeColor = $colors.TextPrimary
    $form.Controls.Add($textBox)

    $okButton = New-Object ModernButton
    $okButton.Location = New-Object System.Drawing.Point(150,100)
    $okButton.Size = New-Object System.Drawing.Size(100,40)
    $okButton.Text = "OK"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $okButton.BackColor = $colors.AccentBlue
    $okButton.ForeColor = [System.Drawing.Color]::White
    $okButton.FlatAppearance.BorderSize = 0
    $form.Controls.Add($okButton)

    $form.AcceptButton = $okButton
    $result = $form.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) { return $textBox.Text }
    return $null
}

function Set-ControlsState($enabled) {
    $listView.Enabled = $textBox.Enabled = $addButton.Enabled = $removeButton.Enabled = 
    $comboBox.Enabled = $deleteListButton.Enabled = $setDefaultListButton.Enabled = $enabled
    $script:undoListButton.Visible = $script:undoItemButton.Visible = $false
}

function Resize-Controls {
    $margin = 10
    $spacing = 10
    $buttonHeight = 35
    $listView.Location = New-Object System.Drawing.Point($margin, 50)
    $listView.Size = New-Object System.Drawing.Size(($form.ClientSize.Width - 2 * $margin), ($form.ClientSize.Height - 130 - 2 * $buttonHeight))
    $textBox.Location = New-Object System.Drawing.Point($margin, ($form.ClientSize.Height - 2 * $buttonHeight - 2 * $spacing))
    $textBox.Width = $form.ClientSize.Width - 2 * $margin
    $buttonWidth = ($form.ClientSize.Width - 2 * $margin - 2 * $spacing) / 3
    $addButton.Location = New-Object System.Drawing.Point($margin, ($form.ClientSize.Height - $buttonHeight - $spacing))
    $addButton.Width = $buttonWidth
    $removeButton.Location = New-Object System.Drawing.Point(($margin + $buttonWidth + $spacing), ($form.ClientSize.Height - $buttonHeight - $spacing))
    $removeButton.Width = $buttonWidth
    $script:undoItemButton.Location = New-Object System.Drawing.Point(($margin + 2 * $buttonWidth + 2 * $spacing), ($form.ClientSize.Height - $buttonHeight - $spacing))
    $script:undoItemButton.Width = $buttonWidth
}

# Module 8: ListView Sorting
function Sort-ListView {
    if ($script:currentSortColumn -ne -1) {
        $sortOrder = [System.Windows.Forms.SortOrder]::$script:currentSortOrder
        $listView.ListViewItemSorter = New-Object ListViewItemComparer($script:currentSortColumn, $sortOrder)
        $listView.Sort()
    }
}

Add-Type @"
using System;
using System.Windows.Forms;
using System.Collections;
public class ListViewItemComparer : IComparer {
    private int col;
    private SortOrder order;
    public ListViewItemComparer(int column, SortOrder order) { col = column; this.order = order; }
    public int Compare(object x, object y) {
        int returnVal = -1;
        if (col == 0) {
            bool xChecked = ((ListViewItem)x).Checked;
            bool yChecked = ((ListViewItem)y).Checked;
            returnVal = xChecked.CompareTo(yChecked);
        }
        else if (col == 2 || col == 3) {
            DateTime xDate, yDate;
            if (DateTime.TryParse(((ListViewItem)x).SubItems[col].Text, out xDate) &&
                DateTime.TryParse(((ListViewItem)y).SubItems[col].Text, out yDate)) {
                returnVal = DateTime.Compare(xDate, yDate);
            }
            else {
                returnVal = String.Compare(((ListViewItem)x).SubItems[col].Text,
                                            ((ListViewItem)y).SubItems[col].Text);
            }
        }
        else {
            returnVal = String.Compare(((ListViewItem)x).SubItems[col].Text,
                                        ((ListViewItem)y).SubItems[col].Text);
        }
        if (order == SortOrder.Descending) returnVal *= -1;
        return returnVal;
    }
}
"@ -ReferencedAssemblies System.Windows.Forms

# Module 9: Create Main Form and Controls
$form = New-Object System.Windows.Forms.Form
$form.Text = "ToDo List"
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$form.BackColor = $colors.Background
$form.ForeColor = $colors.TextPrimary

$margin = 10
$spacing = 10
$buttonHeight = 35
$buttonSize = New-Object System.Drawing.Size(160, $buttonHeight)

$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point($margin, 50)
$listView.View = [System.Windows.Forms.View]::Details
$listView.FullRowSelect = $true
$listView.CheckBoxes = $true
$listView.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$listView.BackColor = $colors.ListViewBackground
$listView.ForeColor = $colors.TextPrimary
$listView.GridLines = $false
$listView.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$listView.Columns.Add("", 30)
$listView.Columns.Add("Task", 519)
$listView.Columns.Add("Date Entered", 160)
$listView.Columns.Add("Date Completed", 160)
$form.Controls.Add($listView)

# Create context menu
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$contextMenu.BackColor = $colors.MenuBackground
$contextMenu.Font = New-Object System.Drawing.Font("Segoe UI", 11)

$editMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$editMenuItem.Text = "Edit Task"
$editMenuItem.BackColor = $colors.MenuBackground
$editMenuItem.ForeColor = $colors.TextPrimary
$contextMenu.Items.Add($editMenuItem)

$listView.ContextMenuStrip = $contextMenu

$comboBox = New-Object System.Windows.Forms.ComboBox
$comboBox.Location = New-Object System.Drawing.Point($margin, $margin)
$comboBox.Size = New-Object System.Drawing.Size(250, 30)
$comboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$comboBox.BackColor = $colors.ListViewBackground
$comboBox.ForeColor = $colors.TextPrimary
$comboBox.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$form.Controls.Add($comboBox)

$newListButton = New-Object ModernButton
$newListButton.Location = New-Object System.Drawing.Point((270 + $spacing), $margin)
$newListButton.Size = $buttonSize
$newListButton.Text = "New List"
$form.Controls.Add($newListButton)

$deleteListButton = New-Object ModernButton
$deleteListButton.Location = New-Object System.Drawing.Point((440 + 2 * $spacing), $margin)
$deleteListButton.Size = $buttonSize
$deleteListButton.Text = "Delete List"
$form.Controls.Add($deleteListButton)

$setDefaultListButton = New-Object ModernButton
$setDefaultListButton.Location = New-Object System.Drawing.Point((610 + 3 * $spacing), $margin)
$setDefaultListButton.Size = $buttonSize
$setDefaultListButton.Text = "Set Default List"
$form.Controls.Add($setDefaultListButton)

$script:undoListButton = New-Object ModernButton
$script:undoListButton.Location = New-Object System.Drawing.Point((780 + 4 * $spacing), $margin)
$script:undoListButton.Size = $buttonSize
$script:undoListButton.Text = "Undo Deleted List"
$script:undoListButton.Visible = $false
$form.Controls.Add($script:undoListButton)

$textBox = New-Object PlaceholderTextBox
$textBox.Size = New-Object System.Drawing.Size(300, $buttonHeight)
$textBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$textBox.BackColor = $colors.ListViewBackground
$textBox.ForeColor = $colors.TextPrimary
$textBox.Placeholder = "Enter new task"
$textBox.PlaceholderColor = $colors.PlaceholderText
$form.Controls.Add($textBox)

$addButton = New-Object ModernButton
$addButton.Size = $buttonSize
$addButton.Text = "Add"
$addButton.BackColor = $colors.AccentBlue
$addButton.ForeColor = [System.Drawing.Color]::White
$addButton.FlatAppearance.BorderSize = 0
$form.Controls.Add($addButton)

$removeButton = New-Object ModernButton
$removeButton.Size = $buttonSize
$removeButton.Text = "Remove"
$form.Controls.Add($removeButton)

$script:undoItemButton = New-Object ModernButton
$script:undoItemButton.Size = $buttonSize
$script:undoItemButton.Text = "Undo Deleted Item"
$script:undoItemButton.Visible = $false
$form.Controls.Add($script:undoItemButton)

# Module 10: Event Handlers
$addButton.Add_Click({ Add-Task })
$form.AcceptButton = $addButton
$removeButton.Add_Click({ Remove-SelectedTasks })
$script:undoItemButton.Add_Click({ Undo-DeletedItem })
$script:undoListButton.Add_Click({ Undo-DeletedList })
$newListButton.Add_Click({ New-TodoList })
$deleteListButton.Add_Click({ Remove-TodoList })
$setDefaultListButton.Add_Click({ Set-DefaultList })
$editMenuItem.Add_Click({ Edit-Task })


$listView.Add_ItemChecked({
    $item = $_.Item
    if ($item.Checked) {
        $item.SubItems[1].Font = New-Object System.Drawing.Font($listView.Font, [System.Drawing.FontStyle]::Strikeout)
        $item.SubItems[1].ForeColor = $colors.CompletedTask
        $item.SubItems[3].Text = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    } else {
        $item.SubItems[1].Font = $listView.Font
        $item.SubItems[1].ForeColor = $colors.TextPrimary
        $item.SubItems[3].Text = ""
    }
    Save-Tasks $script:currentList
    Sort-ListView
})

$comboBox.Add_SelectedIndexChanged({
    $script:currentList = $comboBox.SelectedItem
    $listView.Items.Clear()
    $tasks = Load-Tasks $script:currentList
    foreach ($task in $tasks) {
        $item = New-Object System.Windows.Forms.ListViewItem("")
        $item.SubItems.Add($task.Text)
        $item.SubItems.Add($task.DateEntered)
        $item.SubItems.Add($task.DateCompleted)
        $item.Checked = $task.Completed
        $item.UseItemStyleForSubItems = $false
        if ($task.Completed) {
            $item.SubItems[1].Font = New-Object System.Drawing.Font($listView.Font, [System.Drawing.FontStyle]::Strikeout)
            $item.SubItems[1].ForeColor = $colors.CompletedTask
        } else {
            $item.SubItems[1].Font = $listView.Font
            $item.SubItems[1].ForeColor = $colors.TextPrimary
        }
        $listView.Items.Add($item)
    }
    $script:undoItemButton.Visible = $false
    Sort-ListView
})

$form.KeyPreview = $true

$listView.Add_ColumnClick({
    $column = $_.Column
    if ($script:currentSortColumn -eq $column) {
        $script:currentSortOrder = if ($script:currentSortOrder -eq "Ascending") { "Descending" } else { "Ascending" }
    } else {
        $script:currentSortColumn = $column
        $script:currentSortOrder = "Ascending"
    }
    Sort-ListView
    Save-Settings
})

# Module 11: Application Initialization
$settings = Load-Settings
$script:defaultList = $settings.DefaultList
$form.Size = New-Object System.Drawing.Size($settings.WindowWidth, $settings.WindowHeight)
$listView.Columns[0].Width = $settings.Column1Width
$listView.Columns[1].Width = $settings.Column2Width
$listView.Columns[2].Width = $settings.Column3Width
$listView.Columns[3].Width = $settings.Column4Width
$script:currentSortColumn = $settings.SortColumn
$script:currentSortOrder = $settings.SortOrder

$listNames = Load-ListNames
foreach ($listName in $listNames) { $comboBox.Items.Add($listName) }

if ($comboBox.Items.Count -eq 0) {
    Set-ControlsState $false
    New-TodoList
}
else {
    if ($script:defaultList -and $comboBox.Items.Contains($script:defaultList)) {
        $comboBox.SelectedItem = $script:defaultList
    }
    else {
        $comboBox.SelectedIndex = 0
    }
    Set-ControlsState $true
}

$form.Add_FormClosing({ Save-Settings })
$form.Add_Resize({ Resize-Controls })
Resize-Controls

# Module 12: Application Execution
$form.ShowDialog()