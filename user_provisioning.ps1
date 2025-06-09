# user_provisioning.ps1

# Author: Jackson McClain

# Description: This script will be used to automatically provision Azure AD users and groups from a CSV file. This script assumes you have already installed and imported the Microsoft.Graph module

# Connect to Microsoft Graph with only the required scopes
Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All"

# Inputting CSV
$csvPath = ".\users.csv"

# Output file
$logPath = ".\output-log.txt"
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Starting user provisioning script..." | Out-File -FilePath $logPath

# Reading CSV
try {
    $users = Import-Csv -Path $csvPath
    Write-Host "Successfully imported user CSV with $($users.Count) users."
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Reading input file: $csvPath" | Out-File -Append -FilePath $logPath
}
catch {
    Write-Host "Failed to import CSV File. $_"
    exit
}

# Loop through each user for info
foreach ($user in $users) {
    $displayName = "$($user.FirstName) $($user.LastName)"
    $userPrincipalName = "$($user.Username)@jacks90563gmail.onmicrosoft.com"
    $passwordProfile = @{ Password = "Password1!"; ForceChangePasswordNextSignIn = $true }

    Write-Host "Processing user: $displayName ($userPrincipalName)"
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Processing user: $($user.Username)" | Out-File -Append -FilePath $logPath

    # Checking if user already exists and adding to existing group
    try {
        $existingUser = Get-MgUser -UserId $userPrincipalName -ErrorAction Stop
        Write-Host "  -> User already exists. Skipping creation."
        "  -> User already exists. Skipping creation of $($existingUser.DisplayName)" | Out-File -Append -FilePath $logPath

        $group = Get-MgGroup -All:$true | Where-Object { $_.DisplayName -eq $user.Department }
        New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $existingUser.Id
            Write-Host "  -> Added to group: $($group.DisplayName)"
            "  -> Adding to group: $($group.DisplayName)... SUCCESS" | Out-File -Append -FilePath $logPath
        continue
    }
    catch {
        Write-Host "  -> User not found. Proceeding with creation."

        # Creating users
        try {
            $newUser = New-MgUser  -DisplayName $displayName `
                               -UserPrincipalName $userPrincipalName `
                               -AccountEnabled:$true `
                               -PasswordProfile $passwordProfile `
                               -MailNickname $user.Username `
                               -GivenName $user.FirstName `
                               -Surname $user.LastName `
                               -Department $user.Department `
                               -JobTitle $user.JobTitle

            Write-Host "  -> User created successfully"
            "  -> Creating Azure AD user... SUCCESS" | Out-File -Append -FilePath $logPath

            # Group created if needed
            $group = Get-MgGroup -All:$true | Where-Object { $_.DisplayName -eq $user.Department }
                if (-not $group) {
                    try {
                        $group = New-MgGroup  -DisplayName $user.Department `
                                            -MailEnabled:$false `
                                            -MailNickname $user.Department `
                                            -SecurityEnabled:$true `
                                            -GroupTypes @()
                        Write-Host " -> Created group: $($group.DisplayName)"
                        "  -> Created group: $($group.DisplayName)" | Out-File -Append -FilePath $logPath
                    } catch {
                        Write-Warning "  -> Group creation failed: $_"
                        "  -> Group creation failed: $_" | Out-File -Append -FilePath $logPath
                        continue
                    }

                }  
                
                # New user added to group
                New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $newUser.Id
                Write-Host "  -> Added to group: $($group.DisplayName)"
                "  -> Adding to group: $($group.DisplayName)... SUCCESS" | Out-File -Append -FilePath $logPath  
        }
        catch {
            Write-Warning "  -> User creation failed: $_"
            "  -> Creating Azure AD user... FAILED: $_" | Out-File -Append -FilePath $logPath
            continue
        }
    }
}

Write-Host "✅ Provisioning complete."
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Provisioning complete. Total users processed: $($users.Count)" | Out-File -Append -FilePath $logPath
