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
## step 1, update to PS 7.4.0
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

### implement the update
$minPSVer = [version]'7.4.0'
$curPSVer = $PSVersionTable.PSVersion

# Check if the current PowerShell version is less than 7.4
if ($curPSVer -lt $minPSVer) {
    Write-Host "Updating PowerShell.`n"
    try {
        Start-Process -Wait -FilePath "msiexec.exe" -ArgumentList "/i $output1 /qn" -ErrorAction Stop
        Write-Host "PowerShell installation successful.`n`n"
    }
    catch {
        Write-Host "Error installing PowerShell: $_`n`n"
        exit 1
    }
} else {
    Write-Host "PowerShell is already up-to-date. Skipping installation.`n"
}

### show status
$PSVer = $PSVersionTable.PSVersion
Write-Host "PowerShell version after update: $($PSVer.Major).$($PSVer.Minor).$($PSVer.Build)`n`n"


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
if ($env:USERDOMAIN -ne $null) {
    Write-Host "The server is already a domain controller. Skipping domain setup.`n"
} 

else {
$inpDomain = Read-Host -Prompt "Enter your desired Domain: `n"
Write-Host "Okay, making this server the Domain Controller for $inpDomain `n`n"

try {
    Install-ADDSForest -DomainName $inpDomain -DomainMode Win2012R2 -ForestMode Win2012R2 -InstallDns -ErrorAction Stop
    Write-Host "Stood up domain $inpDomain and made this server a Domain Controller`n`n"
}
catch {
    Write-Host "Error with DSForest: $_ `n"
    exit 1
}

}
