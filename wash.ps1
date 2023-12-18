# this powershell script will be used to stand up a windows server
# created Dec 18-20, 2023 by Tiki-Tech-Network-Solutions



Write-Host "__        ___    ____  _   _ "
Write-Host "\ \      / / \  / ___|| | | |"
Write-Host " \ \ /\ / / _ \ \___ \| |_| |"
Write-Host "  \ V  V / ___ \ ___) |  _  |"
Write-Host "   \_/\_/_/   \_\____/|_| |_|"
Write-Host " Windows Auto Server Handling`n`n`n"
                             
##################################
##################################
## step 0, set this code to automatically run on startup

# Path to your serversetup.ps1 script
$scriptPath = Join-Path $PSScriptRoot "wash.ps1"

# Path to the Windows Startup folder
$startupFolder = [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\Windows\Start Menu\Programs\Startup')

# Create a shortcut in the Startup folder
$shortcutPath = Join-Path $startupFolder "ServerSetup.lnk"
$WshShell = New-Object -ComObject WScript.Shell
$shortcut = $WshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`""
$shortcut.Save()

## step 1, update to PS 7.4.0 (win server 2019 normally has 5.1)
$url1 = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/PowerShell-7.4.0-win-x64.msi"
$output1 = "C:\Users\Administrator\Downloads\PowershellUpgrade.msi"

### retrieve the update file
Write-Host "Downloading updated PowerShell file.`n"
if (Test-Path -Path $output1) {
    Write-Host "PowerShell update file already exists. Skipping download.`n`n"
} else {
    try {
        Invoke-WebRequest -Uri $url1 -OutFile $output1 -ErrorAction Stop
        Write-Host "Download successful.`n`n"
    }
    catch {
        Write-Host "Error downloading the PowerShell update file: $_`n`n"
        exit 1
    }
}

### implement the update (normally from 5.1)
$minPSVer = [version]'7.4.0'
$curPSVer = $PSVersionTable.PSVersion

# Check if the current PowerShell version is less than 7.4
if ($curPSVer -lt $minPSVer) {
    Write-Host "Updating PowerShell.`n"
    try {
        Start-Process -Wait -FilePath "msiexec.exe" -ArgumentList "/i $output1 /qn" -ErrorAction Stop
        Write-Host "PowerShell installation successful.`n`n"
        
        ### show status
        $PSVer = $PSVersionTable.PSVersion
        Write-Host "PowerShell version after update: $($PSVer.Major).$($PSVer.Minor).$($PSVer.Build)`n`n"
    }
    catch {
        Write-Host "Error installing PowerShell: $_`n`n"
        exit 1
    }
} else {
    Write-Host "PowerShell is already up-to-date. Skipping installation.`n"
    $PSVer = $PSVersionTable.PSVersion
    Write-Host "Current PowerShell version: $($PSVer.Major).$($PSVer.Minor).$($PSVer.Build)`n`n"
}


##################################
## step 2 install AD tools
if (Get-WindowsFeature -Name AD-Domain-Services | Where-Object { $_.Installed }) {
    Write-Host "AD-Domain-Services feature is already installed. Skipping installation.`n"
} else {
    try {
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -ErrorAction Stop
        Write-Host "Installed AD-Domain-Services.`n"
    }
    catch {
        Write-Host "Error installing Domain Services: $_ `n"
        exit 1
    }
}

##################################
## step 3 become domain controller

### check if the server is already a domain controller
$inpDomain = Read-Host -Prompt "Enter your desired Domain: `n"
Write-Host "Okay, making this server the Domain Controller for $inpDomain `n`n"
#$domainFile = "C:\Users\Administrator\Documents\domainname.txt"
#$inpDomain | Out-File -FilePath $domainFile
#$Dname = Get-Content -Path $domainFile -Raw

#$Dname = ([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain().Name -split '\.')[0]

if ($env:USERDOMAIN -eq $Dname) {
    Write-Host "The server is already a domain controller. Skipping domain setup.`n"
} 

else {

try {
    Install-ADDSForest -DomainName $inpDomain -DomainMode Win2012R2 -ForestMode Win2012R2 -InstallDns -Force -ErrorAction Stop
    Write-Host "Stood up domain $inpDomain and made this server a Domain Controller`n`n"
}
catch {
    Write-Host "Error with DSForest: $_ `n"
    exit 1
}

}

########post reboot will be the first time a normal stock windows server 2019 has >PS 5.1







### step x remove the startup shortcut

Remove-Item $shortcutPath -Force
