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
#Fully stand up all requisite services to make the server into a DC - check
#Assign the Windows Server VM a static IPv4 address and a DNS - check
#Rename the Windows Server VM - check
#Installs AD-Domain-Services - check
#Create an AD Forest, Organizational Units (OU), and users - check
#Configure the server to act as both a DNS server and a Domain Controller. - check
#Integrate the new server into the existing network infrastructure. - check

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

function Provision-ADUser {
    ######## THE BULK OF THIS SECTION WAS ORIGINALLY WRITTEN IN DECEMBER 2023 BY MARCUS NOGUEIRA, BUT IT HAS BEEN UPDATED TO SUIT MY NEEDS

    # Import the Active Directory module
    Import-Module ActiveDirectory

    # Function accepts a prompt, presents it to the user, checks if the input is empty or not. Returns empty or input. Useful for skipping questions.
    function Get-Input {
        param ([string]$prompt)
        $user_input = Read-Host -Prompt $prompt
        if (-not [string]::IsNullOrWhiteSpace($user_input)) {
            return $user_input
        }
        return $null
    }


    do {
        $firstName = Get-Input -prompt "ENTER FIRST NAME "
        $lastName = Get-Input -prompt "ENTER LAST NAME "
        $title = Get-Input -prompt "ENTER TITLE "
        $department = Get-Input -prompt "ENTER DEPARTMENT "
        $company = Get-Input -prompt "ENTER COMPANY "

        $Dname = ([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain().Name -split '\.')[0]
        
        # make the email address
        $emailLastName = $lastName.Substring(0, [Math]::Min(5, $lastName.Length))
        $emailFirstName = $firstName.Substring(0, [Math]::Min(2, $firstName.Length))
        $email = "$emailLastName$emailFirstName@$Dname.com"
        

        # Check for the OU based on the Department
        $OUPath = "OU=$department,DC=$Dname,DC=com"
        if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$department'" -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $department -Path "DC=$Dname,DC=com"
        }

        # User creation
        New-ADUser -Name "$firstName $lastName" `
            -GivenName $firstName `
            -Surname $lastName `
            -SamAccountName ($firstName[0] + $lastName).ToLower() `
            -UserPrincipalName "$email" `
            -Path $OUPath `
            -Title $title `
            -Department $department `
            -Company $company `
            -EmailAddress $email `
            -Enabled $true `
            -AccountPassword (ConvertTo-SecureString "Tikitech1" -AsPlainText -Force) `
            -ChangePasswordAtLogon $true

        Write-Host "A user account has been created in the Active Directory for $firstName $lastName with email address $email. Welcome to $company!"
        $addAnother = Get-Input -prompt "Would you like to add another user? (Y/N)"
    } while ($addAnother -eq "Y")
}

function Server-Maintenance {
    # Prompt user if they want to rename the server
    $renameServer = Read-Host "Would you like to rename the server? (y/n)"

    if ($renameServer -eq "y") {
        # Get user input for the new server name
        $newServerName = Read-Host "Enter the new server name"

        # Print user input for confirmation
        Write-Host "You entered the new server name: $newServerName"

        # Change server name to user input without immediate restart
        Rename-Computer -NewName $newServerName -Force

        # Display message about the change taking effect on reboot
        Write-Host "The server name has been changed to $newServerName. The change will take effect on the next reboot.`n"
    }

    elseif ($renameServer -eq "n") {
        Write-Host "Skipping server rename.`n"
    }

    else {
        Write-Host "Invalid input. Please enter y or n.`n"
        return
    }

    # Prompt user if they want to set a static LAN IP for the server
    $setStaticIP = Read-Host "Would you like to set a static LAN IP and configure DNS for this server? (Y/N)"

    if ($setStaticIP -eq "Y") {
        # Get the static IP address from ipconfig
        $ipConfigResult = ipconfig | Select-String -Pattern 'IPv4 Address.*: (\d+\.\d+\.\d+\.\d+)' -AllMatches
        $staticIP = $ipConfigResult.Matches.Groups[1].Value

        # Validate if a valid IP address was found
        if (-not ($staticIP -as [System.Net.IPAddress])) {
            Write-Host "Unable to retrieve a valid static IP address from ipconfig. Please enter it manually.`n"
            return
        }

        # Get user input for the default gateway
        $defaultGateway = Read-Host "Enter your router IP address (default gateway, IPv4)"
        if (-not ($defaultGateway -as [System.Net.IPAddress])) {
            Write-Host "Invalid gateway IP address format. Please enter a valid IPv4 address.`n"
            return
        }

        # Set static IP address for the server
        $networkAdapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        $interfaceAlias = $networkAdapter.InterfaceAlias
        New-NetIPAddress -InterfaceAlias $interfaceAlias -IPAddress $staticIP -PrefixLength 24 -DefaultGateway $defaultGateway -Type Unicast

        # Display message after the static IP is set
        Write-Host "Static IP address set to $staticIP. Configuring DNS...`n"

        # Import the DNS Server module
        Import-Module DnsServer

        # Define DNS settings
        $IPAddress = $staticIP  # Replace with the actual IP address of your DNS server
        $Forwarders = "8.8.8.8", "8.8.4.4"  # Replace with your preferred DNS forwarders

        # Configure DNS server settings
        if (-not (Get-WindowsFeature -Name DNS -ErrorAction SilentlyContinue)) {
            # Install DNS server feature
            Install-WindowsFeature -Name DNS -IncludeManagementTools
        }

        # Configure DNS server to use root hints
        Set-DnsServerRootHint -ServerName localhost

        # Set the DNS server to listen on all available IP addresses
        Set-DnsServerSetting -InterfaceAlias (Get-NetAdapter).Name -ListenAddresses "Any"

        # Set the DNS server address on the network adapter
        $NIC = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        Set-DnsClientServerAddress -InterfaceIndex $NIC.IfIndex -ServerAddresses $IPAddress

        # Configure DNS forwarders
        Set-DnsServerForwarder -IPAddress $Forwarders

        # Get the current domain name
        $domain = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).Name

        # Create a forward lookup zone (replace "example.com" with your actual domain)
        Add-DnsServerPrimaryZone -Name $domain -ZoneFile "$domain.dns"

        # Restart DNS service to apply changes
        Restart-Service -Name DNS

        # Display message after DNS is configured
        Write-Host "DNS configuration completed. Exiting maintenance.`n"
    }
    elseif ($setStaticIP -eq "N") {
        Write-Host "Skipping static IP configuration. Exiting maintenance.`n"
    }
    else {
        Write-Host "Invalid input. Please enter Y or N.`n"
        return
    }
}

# Display the menu
while ($true) {
    Clear-Host
    Write-Host "Select an option:"
    Write-Host "1. Download and install PowerShell 7.4 update"
    Write-Host "2. Install Active Directory Domain Services"
    Write-Host "3. Promote this server to a Domain Controller"
    Write-Host "4. Add AD Users or OUs to the Domain"
    Write-Host "5. Server Maintenance - Rename, Static IP, DNS"
    Write-Host "Q. Quit"

    # Get user input
    $choice = Read-Host "Enter the number or 'Q' to quit"

    # Process user choice
    switch ($choice) {
        '1' { Download-Install-PowerShell7.4; break }
        '2' { Install-AD-Domain-Services; break }
        '3' { Create-Domain-Controller; break }
        '4' { Provision-ADUser; break }
        '5' { Server-Maintenance; break }
        'Q' { exit }
        default { Write-Host "Invalid choice. Please try again." }
    }

    # Pause to display the output
    Read-Host "Press Enter to continue..."
}
