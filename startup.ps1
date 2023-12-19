# Unique process name to check if the script is already running
$processName = "ExampleScript"

# Log file path
$logFilePath = Join-Path $env:TEMP "ExampleScript_Log.txt"

# Check if the process is already running
if (-not (Get-Process -Name $processName -ErrorAction SilentlyContinue)) {

    # Path to your startup.ps1 script
    $scriptPath = Join-Path $PSScriptRoot "startup.ps1"

    # Path to the Windows Startup folder
    $startupFolder = [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\Windows\Start Menu\Programs\Startup')

    # Name of the shortcut
    $shortcutName = "ExampleText.lnk"

    # Full path to the shortcut
    $shortcutPath = Join-Path $startupFolder $shortcutName

    # Log message function
    function Log-Message {
        param (
            [string]$Message
        )
        $Message | Out-File -Append -LiteralPath $logFilePath
        Write-Host $Message
    }

    # Log start of script
    Log-Message "Script started at $(Get-Date)"

    # Check if the shortcut already exists
    if (-not (Test-Path $shortcutPath)) {
        # Create a shortcut in the Startup folder
        $WshShell = New-Object -ComObject WScript.Shell
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "C:\Program Files\PowerShell\7\pwsh.exe"
        $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`""
        $shortcut.Save()

        Log-Message "Shortcut created in the Startup folder."
    } else {
        Log-Message "Shortcut already exists in the Startup folder."
        return
    }

    # Start the PowerShell script and wait for it to finish
    Start-Process -FilePath "C:\Program Files\PowerShell\7\pwsh.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -Wait -NoNewWindow

    Log-Message "The start-up script has finished running."
    return

} else {
    Log-Message "The script is already running. Exiting."
    return
}
