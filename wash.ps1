# this powershell script will be used to stand up a windows server
# created Dec 18-20, 2023 by Tiki-Tech-Network-Solutions



Write-Host "__        ___    ____  _   _ "
Write-Host "\ \      / / \  / ___|| | | |"
Write-Host " \ \ /\ / / _ \ \___ \| |_| |"
Write-Host "  \ V  V / ___ \ ___) |  _  |"
Write-Host "   \_/\_/_/   \_\____/|_| |_|"
Write-Host " Windows Auto Server Handling`n`n`n"

Write-Host "Procedurally, this script will set itself to automatically launch on reboot, then optionally download and install a PowerShell update (to 7.4.0 using GitHub). `nNext, it will optionally Active Directory Domain Services, prompt for a domain, and make this device a domain controller within that domain. The script will also prompt to set a static IP in the server software.`nAfter that, it will iteratively prompt the user to create OUs and users."
                             
##################################

#Objectives:
#Fully stand up all requisite services to make the server into a DC
#Assign the Windows Server VM a static IPv4 address and a DNS
#Rename the Windows Server VM
#Installs AD-Domain-Services
#Create an AD Forest, Organizational Units (OU), and users
#Configure the server to act as both a DNS server and a Domain Controller.
#Integrate the new server into the existing network infrastructure.

##################################
function Download-Install-PowerShell7.4 {
    ## Step 1: Update to PowerShell 7.4.0 (Windows Server 2019 normally has 5.1)
    $url1 = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/PowerShell-7.4.0-win-x64.msi"
    $output1 = "C:\Users\Administrator\Downloads\PowershellUpgrade.msi"

    ### Retrieve the update file
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

    ### Implement the update (normally from 5.1)
    $minPSVer = [version]'7.4.0'
    $curPSVer = $PSVersionTable.PSVersion

    # Check if the current PowerShell version is less than 7.4
    if ($curPSVer -lt $minPSVer) {
        Write-Host "Updating PowerShell.`n"
        try {
            Start-Process -Wait -FilePath "msiexec.exe" -ArgumentList "/i $output1 /qn" -ErrorAction Stop
            Write-Host "PowerShell installation successful.`n`n"
            
            ### Show status
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
}

function Install-AD-Domain-Services {
    ## Step 2: Install AD tools
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
}

function Create-Domain-Controller {
    ## Step 3: Become domain controller
    ### Check if the server is already a domain controller
    $inpDomain = Read-Host -Prompt "Enter your desired Domain:`n"
    Write-Host "Okay, making this server the Domain Controller for $inpDomain`n`n"

    $Dname = ([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain().Name -split '\.')[0]

    if ($env:USERDOMAIN -eq $Dname) {
        Write-Host "The server is already a domain controller. Skipping domain setup.`n"
    } else {
        try {
            Install-ADDSForest -DomainName $inpDomain -DomainMode Win2012R2 -ForestMode Win2012R2 -InstallDns -Force -ErrorAction Stop
            Write-Host "Stood up domain $inpDomain and made this server a Domain Controller`n`n"
        }
        catch {
            Write-Host "Error with DSForest: $_ `n"
            exit 1
        }
    }
}

# Display the menu
while ($true) {
    Clear-Host
    Write-Host "Select an option:"
    Write-Host "1. Download and install PowerShell 7.4 update"
    Write-Host "2. Install Active Directory Domain Services"
    Write-Host "3. Create the Domain Controller"
    Write-Host "Q. Quit"

    # Get user input
    $choice = Read-Host "Enter the number or 'Q' to quit"

    # Process user choice
    switch ($choice) {
        '1' { Download-Install-PowerShell7.4; break }
        '2' { Install-AD-Domain-Services; break }
        '3' { Create-Domain-Controller; break }
        'Q' { exit }
        default { Write-Host "Invalid choice. Please try again." }
    }

    # Pause to display the output
    Read-Host "Press Enter to continue..."
}
