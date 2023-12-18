# this powershell script will be used to stand up a windows server
# created Dec 18-20, 2023 by Tiki-Tech-Network-Solutions

## step 1, update to PS 7.2.0
$url1 = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/PowerShell-7.4.0-win-x64.msi"
$output1 = "C:\Users\Administrator\Downloads\PowershellUpgrade.msi"

### retrieve the update file
Write-Host "Downloading updated PowerShell file.`n"
try {
    Invoke-WebRequest -Uri $url1 -OutFile $output1 -ErrorAction Stop
    Write-Host "Download successful.`n`n"
}
catch {
    Write-Host "Error downloading the MSI file: $_`n`n"
    exit 1
}


### implement the update
Write-Host "Updating PowerShell.`n"
try {
    Start-Process -Wait -FilePath "msiexec.exe" -ArgumentList "/i $output1 /qn" -ErrorAction Stop
    Write-Host "PowerShell installation successful.`n`n"
}
catch {
    Write-Host "Error installing PowerShell: $_`n`n"
    exit 1
}

### show status
$PSVer = $PSVersionTable.PSVersion
Write-Host "PowerShell version after update: $($PSVer.Major).$($PSVer.Minor).$($PSVer.Build)`n`n"


## step 2 install AD tools
try {
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -ErrorAction Stop
    Write-Host "Installed AD-Domain-Services.`n"
}
catch {
    Write-Host "Error installing Domain Services: $_ `n"
    exit 1
}

## step 3 become domain controller

$inpDomain = Read-Host -Prompt "Enter your desired Domain: `n"
Write-Host "Okay, making this server the Domain Controller for $inpDomain `n`n"

try {
    Install-ADDSForest -DomainName $inpDomain -DomainMode Win2019 -ForestMode Win2019 -InstallDns -ErrorAction Stop
    Write-Host "Stood up domain $inpDomain and made this server a Domain Controller`n`n"
}
catch {
    Write-Host "Error with DSForest: $_ `n"
    exit 1
}


