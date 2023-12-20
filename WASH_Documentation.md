# Windows Automated Server Handling (WASH)
Documentation and Walkthrough

The purpose of this script, written in PowerShell - compatible with 5.1+, is to significantly automate the initial configuration of Windows Server 2019.


The script was created Dec 18-21, 2023 by Ian Bennett for Tiki-Tech-Network-Solutions (Ops301, CodeFellows, Seattle, WA). Big thanks to Jaime Angel and Juan Cano for helping with the testing on their machines.


This documentation was created on 20 Dec by Ian Bennett to explain the script. There will certainly be edits to the script after completion of the documentation, but the bulk of this document should remain relevant and explicative.


## Intro


This section launches a micro-splash and has some line breaks to clearly lead into the program in CLI tools.

>Write-Host "__        ___    ____  _   _ "
>
>Write-Host "\ \      / / \  / ___|| | | |"
>
>Write-Host " \ \ /\ / / _ \ \___ \| |_| |"
>
>Write-Host "  \ V  V / ___ \ ___) |  _  |"
>
>Write-Host "   \_/\_/_/   \_\____/|_| |_|"
>
>Write-Host " Windows     Automated       `n"
>
>Write-Host "       Server       Handling`n`n`n"
>
>Start-Sleep -Seconds 1.5



## Functions


This section defines the functions that form a later menu for ease of use. 


### PowerShell Updater

An obvious issue is that Windows Server 2019 ships with PS 5.1.x, so this section pretty simply installs 7.4.0 in parallel to 5.1.

Procedurally, it first opens the function, then:

> function Download-Install-PowerShell7.4 {

Defines the static web address for the GitHub location of the 7.4 .msi (a different source could be hard-coded later) and the target directory for downloads as variables.

>    $url1 = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/PowerShell-7.4.0-win-x64.msi"
>    $output1 = "C:\Users\Administrator\Downloads\PowershellUpgrade.msi"

Then checks to see whether the PowerShell update file ($output1) already exists - useful for late-night configuration or when errors occur in installation to reduce bandwidth use. This uses try-catch to look for the file and Invoke-WebRequest to actually download it.

>    Write-Host "Downloading updated PowerShell file.`n"
>    if (Test-Path -Path $output1) {
>        Write-Host "PowerShell update file already exists. Skipping download.`n`n"
>    } else {
>        try {
>            Write-Host "A previous download of the PowerShell update was not found. Downloading the file from GitHub.`n"
>            Invoke-WebRequest -Uri $url1 -OutFile $output1 -ErrorAction Stop
>            Write-Host "Download successful.`n`n"
>        }
>        catch {
>            Write-Host "Error downloading the PowerShell update file: $_`n`n"
>            exit 1
>        }
>    }


Next, the current PowerShell version (normally 5.1) is pulled from system variables, and compared to the desired target (7.4, but could be changed). If the desired PS version is not found, then the script installs from the downloaded file. Again using try-catch, if the PS version is up to date, installation is skipped. There's also some error handling here that should spit out Windows codes for anything that goes wrong.

>     $minPSVer = [version]'7.4.0'
>     $curPSVer = $PSVersionTable.PSVersion
>
>     if ($curPSVer -lt $minPSVer) {
>        Write-Host "Your PowerShell version is less than 7.4.0 - updating PowerShell.`n"
>        try {
>            Start-Process -Wait -FilePath "msiexec.exe" -ArgumentList "/i $output1 /qn" -ErrorAction Stop
>            Write-Host "PowerShell installation successful.`nOne note - if you're running this in a 5.1 session, the version won't show as 7.4 but it probably did install.`n"
>            
>            $PSVer = $PSVersionTable.PSVersion
>            Write-Host "PowerShell version after update (in this session): $($PSVer.Major).$($PSVer.Minor).$($PSVer.Build)`n`n"
>        }
>
>        catch {
>            Write-Host "Error installing PowerShell: $_`n`n"
>            exit 1
>        }
>      } else {
>        Write-Host "PowerShell is already up-to-date. Skipping installation.`n"
>        $PSVer = $PSVersionTable.PSVersion
>        Write-Host "Current PowerShell version (in this session): $($PSVer.Major).$($PSVer.Minor).$($PSVer.Build)`n`n"
>    }
>}

You may notice the $PSVer is redefined at the end. I frankly couldn't figure out how else to check for installation, but right now this is not a useful check because it only reports the PS version of the session the user is running (which normally won't be 7.4 until later).

##################################

## Installing Active Directory Domain Services (ADDS)

In this function, the script first checks for a previous installation of the WindowsFeature ADDS, then if it is found -> skips, and if not found -> installs. This is all native Windows process, so no user input required like a target download directory. It does include `-ErrorAction Stop` and try-catch error handling just in case. This is Windows, after all.


>  function Install-AD-Domain-Services {
   
>      if (Get-WindowsFeature -Name AD-Domain-Services | Where-Object { $_.Installed }) {
>>          Write-Host "AD-Domain-Services feature is already installed. Skipping installation.`n"
>      } else {
>          try {
>>              Write-Host "Previous download of ADDS was not found. Downloading..."
>>              Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -ErrorAction Stop
>>              Write-Host "Installed AD-Domain-Services.`n"
>          }
>          catch {
>>             Write-Host "Error installing Domain Services: $_ `n"
>>             exit 1
>         }
>     }
> }

##################################

## Create A Domain, Install DNS, Set Domain Controller

This function is intended to make a new domain and set this Domain as a Domain Controller - recall the purpose of the script is creation of a new infrastructure. There are plenty of one-liners out there to add a new server to existing infrastructure and promote the server to DC. This ain't that.

> function Create-Domain-Controller {

There's a warning here because during the check for "are you already in a Domain?", if you're not, then Windows throws a warning in CLI - but it literally doesn't matter at all because that's the desired outcome.

>    Write-Host "If you are not yet a member of a domain (like during initial configuration) then you'll get a red font error right here when the variable you can't see tries to check your current domain. It's no big deal."

Here I define the name of the directory (just "example" not "example.com") using system variables. Windows won't find it if the server isn't joined to a Domain.

>    $Dname = ([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain().Name -split '\.')[0]

Assuming the Domain is found, 
>    if ($env:USERDOMAIN -eq $Dname) {

The script will report it is skipping Domain setup.

>    Write-Host "The server is already a domain controller for the domain $Dname. Skipping domain setup.`n"

If not, the script will take user input for a Domain name then launch the ADDS Forest setup - a Windows process, not coded here - to set the server as DC and install DNS. This step can take a while depending on resources available to the server - in VMs, it has averaged 5-15 minutes for me.

    }   else {
            try {
                $inpDomain = Read-Host -Prompt "Enter your desired Domain:`n"

                Write-Host "Okay, making this server the Domain Controller for $inpDomain`n Server will prompt for password and reboot during this process.`n`n"

                Install-ADDSForest -DomainName $inpDomain -DomainMode Win2012R2 -ForestMode Win2012R2 -InstallDNS -Force -ErrorAction Stop
            }
            catch {
                Write-Host "Error with DSForest: $_ `n"
                exit 1
         }
        }
    }

##################################

## Provisioning AD-User and AD-OU (interactive)

This function exists to populate the AD. Pretty straightforward. About 70% of the original skeleton of this function was written by a colleague, Marcus Nogueira - particularly the `Get-Input` function, which skips input for a blank user 'enter' press.

Open the function and import the AD module:

> function Provision-ADUser {
>
>    Import-Module ActiveDirectory

This embedded function accepts a prompt, presents it to the user, checks if the input is empty or not. Returns empty or input. Useful for skipping questions.

>    function Get-Input {
>    
> >   param ([string]$prompt)
>
> >   $user_input = Read-Host -Prompt $prompt
>
>>    if (-not [string]::IsNullOrWhiteSpace($user_input)) {
>
>>>  return $user_input
>
>>>    }
>
>>    return $null
>
>    }

Moving into the actual interaction, the script asks whether to make AD-Users (which can also create new OU through the `Department` entry) or OU only, read as $thisorthat.

>    $thisorthat = Read-Host "Press 1 to enter a new AD user and 2 to enter a new OU. Press Q to quit."

Then, the domain name is read again. This is just to make sure we have it correct from Windows in case the tool is being used for ad hoc changes and not during total system configuration.

>    $Dname = ([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain().Name -split '\.')[0]

Next, we use the earlier embedded function and iterate through entry of an AD-User's info. The input is all taken as variables first,
>    if ($thisorthat -eq '1') {
>>        do {
>>>            Write-Host "The following prompts are used to create a user email (first 5 of last name, first 2 of first name).`nIf the department is not found, it will create an AD-OU with that name.`n"

>>>            $firstName = Get-Input -prompt "ENTER FIRST NAME "
>>>            $lastName = Get-Input -prompt "ENTER LAST NAME "
>>>            $title = Get-Input -prompt "ENTER TITLE "
>>>            $department = Get-Input -prompt "ENTER DEPARTMENT "
>>>            $company = Get-Input -prompt "ENTER COMPANY "

Then the input is used to actually create standardized email addresses:        
>>>            $emailLastName = $lastName.Substring(0, [Math]::Min(5, $lastName.Length))
>>>            $emailFirstName = $firstName.Substring(0, [Math]::Min(2, $firstName.Length))
>>>            $email = "$emailLastName$emailFirstName@$Dname.com"
        
Next, the `Department` is handled to see whether it exists as an OU or not. If it does exist, nothing happens here; if it does **not** exist, then a new OU with the `Department` name is created.

>>>            $OUPath = "OU=$department,DC=$Dname,DC=com"
>>>            if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$department'" -ErrorAction SilentlyContinue)) {
>>>>                New-ADOrganizationalUnit -Name $department -Path "DC=$Dname,DC=com"
>>>            }

Next, the AD-User is actually created using the information taken from the user (you). Note there's a hardcoded temporary password here that must be changed on first login. That's not a best practice, but it was fine in my use case.

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

The script prompts to get user input on whether to create additional users or not. If not, the script exits to the higher menu. If yes, the above is repeated using the below 'while'.

            $addAnother = Get-Input -prompt "Would you like to add another user? (Y/N)"
        } while ($addAnother -eq "Y")
    }

If the user selected 2 at the prompt to bypass AD-User creation and just make OUs, this is where it happens. It is really basic - take user input, make the OU, report back, give a list of current OUs, and ask if the user wants to make another OU or not. This will iterate until broken by the user.


    elseif ($thisorthat -eq '2') {
        do{

            $newOU = Read-Host "Enter the name of the Organizational Unit you'd like to create."
            New-ADOrganizationalUnit -Name $newOU -Path "DC=$Dname,DC=com"
            Write-Host "The OU $newOU has been created.`n"

            Write-Host "Here is a list of current OUs:"
            Get-ADOrganizationalUnit -Filter * | Select-Object Name | Format-List
            Write-Host "`n`n"

            $addAnother = Get-Input -prompt "Would you like to add another OU? (Y/N)"
        } while ($addAnother -eq "Y")
    }


There's also an escape if the user doesn't want to add AD-Users or make new OUs, in case of fat-fingering or changed minds.

    elseif ($thisorthat -eq 'Q') {
        break
    }


Also error handling.

    else {
        Write-Host "Invalid input."
        return
    }
}

##################################

## Server Maintenance Function

This function includes renaming the server, setting of a static IP, and configuring this server as the DNS (since it hosts the Domain).

> function Server-Maintenance {
>    
>>    $renameServer = Read-Host "Would you like to rename the server? (y/n)"

>>    if ($renameServer -eq "y") {

This takes user input for the name, prints to screen, and then implements.
>>        $newServerName = Read-Host "Enter the new server name"
>>        Write-Host "You entered the new server name: $newServerName"
>>        Rename-Computer -NewName $newServerName -Force

Warn the user that the server needs to restart to change the name, and offers to execute.
>>        Write-Host "The server name has been changed to $newServerName. The change will take effect on the next reboot.`n"
>>        $turnoff = Read-Host "Would you like to restart now? y/n"

If the user is ready to restart (best choice), then it prompts for a comment and executes here:
>>        if ($turnoff -eq 'y') {
>>>            $comment = Read-Host "Enter a comment explaining the reason for the server reboot"
>>>            Write-Host "You entered: $comment"
>>>            shutdown /f /t 0 /r /c "$comment"
>>        }


If the user is not ready to reboot (worst choice), then the Server Rename segment breaks.

>        elseif ($turnoff -eq 'n') {
>            break
>        }

Input checking.
>        else {
>            Write-Host "Invalid input"
>            return
>        }
>    }

If the user skips renaming the server:
>    elseif ($renameServer -eq "n") {
>        Write-Host "Skipping server rename.`n"
>    }

Input checking.
>    else {
>        Write-Host "Invalid input. Please enter y or n.`n"
>        return
>    }

Prompt user if they want to set a static LAN IP for the server on the server's adapter. Must also be configured (separately) as a reserved IP on the router, as appropriate.
>    $setStaticIP = Read-Host "Would you like to set a static LAN IP and configure DNS for this server? (Y/N)"

If yes:
>    if ($setStaticIP -eq "Y") {

Get the active network adapter:
>>        $networkAdapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
>>        $interfaceAlias = $networkAdapter.InterfaceAlias

Get the static IP address from `ipconfig` and print to screen.
>>        $ipConfigResult = ipconfig | Select-String -Pattern 'IPv4 Address.*: (\d+\.\d+\.\d+\.\d+)' -AllMatches
>>        $staticIP = $ipConfigResult.Matches.Groups[1].Value
>>        Write-Host "Your current IP address (ipconfig) is $staticIP`n"

Validate if a valid IP address was found and if not, prompt for user input. Useful if the server is not connected to the network yet but perhaps less common.
>>        if (-not ($staticIP -as [System.Net.IPAddress])) {
>>>            Write-Host "Unable to retrieve a valid static IP address from ipconfig. Please enter it manually.`n"
>>>            return
>>        }

Get default gateway from `ipconfig` - normally a router - and print to screen.
>>        $ipConfigResult = ipconfig | Select-String -Pattern 'Default Gateway.*: (\d+\.\d+\.\d+\.\d+)' -AllMatches
>>        $defaultGateway = $ipConfigResult.Matches.Groups[1].Value
>>        Write-Host "Your current Gateway address (ipconfig) is $defaultGateway`n"

Validate default gateway ip address, and if not valid, prompt for user input.
>>        if (-not ($defaultGateway -as [System.Net.IPAddress])) {
>>>            Write-Host "Unable to retrieve a valid default gateway from ipconfig. Please enter it manually.`n"
>>>            return
>>        }

Check if the IP address already exists, or said another way, see if the IP address is already configured on the server's NIC (it normally is if the `ipconfig` was able to read it).
>>        $existingIPAddress = Get-NetIPAddress -InterfaceAlias $interfaceAlias | Where-Object { $_.IPAddress -eq $staticIP -and $_.AddressFamily -eq 'IPv4' }

If the IP address exists, delete from the NIC so we can re-apply it cleanly in the next step. All the same settings are applied because everything is saved as variables; unless the user had to input the new IP address because something was wrong with the previous configuration.
>>        if ($existingIPAddress) {
>>>            Remove-NetIPAddress -InterfaceAlias $interfaceAlias -IPAddress $staticIP
>>>            Write-Host "Removed existing IP address $staticIP."
>>        }

>>        New-NetIPAddress -InterfaceAlias $interfaceAlias -IPAddress $staticIP -PrefixLength 24 -DefaultGateway $defaultGateway -Type Unicast -AddressFamily IPv4
>>        Write-Host "Static IP address set to $staticIP."

Next, moves to DNS setup.
>        Write-Host "Importing DNS Server Module"
>        Import-Module DnsServer

Define DNS settings. I left Google remote DNS as the forward but this could be hardcoded elsewhere, like 1.1.1.1 for CloudFlare, or changed to take user input as appropriate.
>        $IPAddress = $staticIP
>        $Forwarders = "8.8.8.8", "8.8.4.4"

Checks for previous installation of DNS - might exist depending on what has been done so far and if it does, the check saves time.
>        Write-Host "Checking for Windows DNS Management features."

If it isn't found, then this installs the WindowsFeatures.
>        if (-not (Get-WindowsFeature -Name DNS -ErrorAction SilentlyContinue)) {
>>            Write-Host "Installing Windows DNS Management features."
>>            Install-WindowsFeature -Name DNS -IncludeManagementTools
>>        }
>>        Write-Host "Setting DNS Server on the active network adapter (typically LAN)"

Also sets the NIC to be the DNS Server address (seems obvious?) - in my use case this is also configured in the router GUI.
>>        $NIC = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
>>        Set-DnsClientServerAddress -InterfaceIndex $NIC.IfIndex -ServerAddresses $IPAddress

This is where the server sends DNS requests to google or wherever is hardcoded.
>        Write-Host "Setting DNS Forwarding to $forwarders"
>        Set-DnsServerForwarder -IPAddress $Forwarders

This section leads into DNS Forward Zone creation to help devices find the Domain we're working in. 

First, pulls the domain name from the Windows variables
>        $domain = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).Name

Then checks whether the Lookup Zone already exists (won't exist in initial config, but might in later maintenance).
>        $zoneExists = Get-DnsServerZone -Name $domain -ErrorAction SilentlyContinue

If the zone exists, skips, and if not, try-catch to make the zone.
>        if ($zoneExists) {
>>            Write-Host "DNS zone for $domain already exists. Skipping creation."
>        } else {
>>            Write-Host "Attempting to create forward lookup zone for $domain on LAN"
>>            try {
>>>                Add-DnsServerPrimaryZone -Name $domain -ZoneFile "$domain.dns" -PassThru -ErrorAction Stop
>>>                Write-Host "Forward lookup zone created successfully."
>>            } catch {
>>>                Write-Host "Failed to create forward lookup zone. Error: $_"
>>            }
>        }

Then restart the DNS service and report success; break the section.
>>        Write-Host "Restarting DNS Service"
>>        Restart-Service -Name DNS
>>        Write-Host "DNS configuration completed. Exiting maintenance.`n"
>    }

Back to static IP - if there's user input to skip static IP config, then IP and DNS are both skipped.
>    elseif ($setStaticIP -eq "N") {
>>        Write-Host "Skipping static IP configuration. Exiting maintenance.`n"
>    }
>    else {
>>        Write-Host "Invalid input. Please enter Y or N.`n"
>>        return
>    }
>
> }

##################################

function Create-Network-Folders {
#    # Prompt user for folder name
#    $folderName = Read-Host "Enter the name of the shared folder"

#    # Validate folder name
#    if (-not $folderName -or $folderName -notmatch '^[a-zA-Z0-9_\-]+$') {
#        Write-Host "Invalid folder name. Please use alphanumeric characters, underscores, or hyphens."
#        return
#    }

#    # Check if folder already exists
#    $folderPath = "C:\SharedFolders\$folderName"
#    $sharePath = "\\$env:COMPUTERNAME\SharedFolders\$folderName"
#    if (Test-Path $folderPath) {
#        Write-Host "The folder '$folderName' already exists. Aborting."
#        return
#    }

#    # Create the folder
#    New-Item -Path $folderPath -ItemType Directory -ErrorAction Stop

#    # Share the folder and assign access based on OUs
#    try {
#        # Share the folder using net share
#        net share $folderName=$sharePath /GRANT:Everyone,0 /GRANT:"Domain Admins",READ

#        # Add access control based on OUs
#        foreach ($ou in $allowedOUs) {
#            $domainComponents = (Get-ADDomain).DistinguishedName -split ',' | ForEach-Object { $_ -replace 'DC=' }
#            $ouPath = "OU=$ou,$domainComponents"
#            net share $folderName /GRANT:$ouPath,CHANGE
#        }   

#        Write-Host "Shared folder '$folderName' created and shared successfully with access control for selected OUs."
#    }  
#    catch {
#        Write-Host "Error sharing folder: $_"
#    }
#}

##################################

function ConfigureEmail {

    # Install SMTP Server feature
    Write-Host "Installing Windows Feature SMTP-Server"
    Install-WindowsFeature -Name SMTP-Server -IncludeManagementTools

    # Import the WebAdministration module
    Write-Host "Importing Module WebAdministration"
    Import-Module WebAdministration

    # Set the SMTP server configuration
    Set-ItemProperty -Path "IIS:\SmtpServer\Default SMTP Server" -Name "SmtpMaxMessagesPerConnection" -Value 20
    Set-ItemProperty -Path "IIS:\SmtpServer\Default SMTP Server" -Name "SmtpMaxMessageSize" -Value 10485760  # 10 MB limit
    Set-ItemProperty -Path "IIS:\SmtpServer\Default SMTP Server" -Name "SmtpMaxRecipientsPerMessage" -Value 100  

    # Disable Anonymous Authentication and enable Windows Authentication
    Set-ItemProperty -Path "IIS:\SmtpServer\Default SMTP Server" -Name "SmtpAnonymousAuthenticationEnabled" -Value $false
    Set-ItemProperty -Path "IIS:\SmtpServer\Default SMTP Server" -Name "SmtpWindowsAuthenticationEnabled" -Value $true

    # Restart the SMTP server to apply changes
    Restart-Service -Name "SimpleMailTransferProtocol"

    Write-Host "SMTP Server configured successfully."
}

##################################

# Display the menu
while ($true) {
    Clear-Host
    Write-Host "Select an option:"
    Write-Host "1. Download and install PowerShell 7.4 update"
    Write-Host "2. Install Active Directory Domain Services"
    Write-Host "3. Promote this server to a Domain Controller"
    Write-Host "4. Add AD Users or OUs to the Domain"
    Write-Host "5. Server Maintenance - Rename, Static IP, DNS"
    Write-Host "6. Create Shared Network Folders"
    Write-Host "7. Configure Intranet Email Server"
    Write-Host "Q. Quit"

    # Get user input
    $choice = Read-Host "Enter the 'Q' to quit"

    # Process user choice
    switch ($choice) {
        '1' { Download-Install-PowerShell7.4; break }
        '2' { Install-AD-Domain-Services; break }
        '3' { Create-Domain-Controller; break }
        '4' { Provision-ADUser; break }
        '5' { Server-Maintenance; break }
        '6' { Create-Network-Folders; break }
        '7' { ConfigureEmail; break }
        'Q' { exit }
        default { Write-Host "Invalid choice. Please try again." }
    }

    # Pause to display the output
    Read-Host "Press Enter to continue..."
}
