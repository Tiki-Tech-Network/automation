# this powershell script will be used to stand up a windows server
# created Dec 18-20, 2023 by Tiki-Tech-Network-Solutions

## step 1, update to PS 7.2.0 from stock PS 5.x
$url1 = "https://github.com/PowerShell/PowerShell/releases/download/v7.2.0/PowerShell-7.2.0-win-x64.msi"
$output1 = "C:\Users\Administrator\Downloads\PowershellUpgrade.msi"

### retrieve the update file
try {
    Invoke-WebRequest -Uri $url1 -OutFile $output1 -ErrorAction Stop
    Write-Host "Download successful.`n`n"
}
catch {
    Write-Host "Error downloading the MSI file: $_`n`n"
    exit 1
}


### implement the update
try {
    Start-Process -Wait -FilePath "msiexec.exe" -ArgumentList "/i $output1 /qn" -ErrorAction Stop
    Write-Host "PowerShell installation successful.`n`n"
}
catch {
    Write-Host "Error installing PowerShell 7.2.0: $_`n`n"
    exit 1
}

### show status
$PSVer = $PSVersionTable.PSVersion
Write-Host "PowerShell version after update: $($PSVer.Major).$($PSVer.Minor).$($PSVer.Build)`n`n"

