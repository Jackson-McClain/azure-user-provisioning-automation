# user_provisioning.ps1

# Author: Jackson McClain

# Description: This script will be used to automatically provision an Azure AD users from a CSV file

# Import AzureAD module unless it is already imported
Import-Module AzureAD -ErrorAction Stop

# Inputting CSV
$csvPath = ".\users.csv"

# Output file
$logPath = ".\output-log.txt"
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Starting user provisioning script..." | Out-File -FilePath $logPath

# Connecting to AzureAD 
if (-not (Get-AzureADTenantDetail -ErrorAction SilentlyContinue)) {
    Write-Host "Connecting to Azure AD..."
    Connect-AzureAD
}

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
    $userPrincipalName = "$($user.Username)@fakeemaildomain.com"
    $password = Read-Host "Enter a default password" -AsSecureString

    Write-Host "Processing user: $displayName ($userPrincipalName)"
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Processing user: $($user.Username)" | Out-File -Append -FilePath $logPath

    # Creating users in AzureAD
    try {
        $newUser = New-AzureADUser -DisplayName $displayName -UserPrincipalName $userPrincipalName -AccountEnabled $true -PasswordProfile @{ Password = $password; ForceChangePasswordNextLogin = $true } -MailNickName $user.Username -GivenName $user.FirstName -Surname $user.LastName -Department $user.Department -JobTitle $user.JobTitle

        Write-Host "  -> User created successfully"
        "  -> Creating Azure AD user... SUCCESS" | Out-File -Append -FilePath $logPath
    }
    catch {
        Write-Warning "  -> User creation failed: $_"
        "  -> Creating Azure AD user... FAILED: $_" | Out-File -Append -FilePath $logPath
        continue
    }

    # Adding user to dept. group. Group created if needed
    $group = Get-AzureADGroup -All $true | Where-Object { $_.DisplayName -eq $user.Department }
    if ($group) {
        try {
            Add-AzureADGroupMember -ObjectId $group.ObjectID -RefObjectId $newUser.ObjectID
            Write-Host "  -> Added to group: $($group.DisplayName)"
            "  -> Adding to group: $($group.DisplayName)... SUCCESS" | Out-File -Append -FilePath $logPath
        }
        catch {
            $group = New-AzureADGroup -DisplayName $user.Department -SecurityEnabled $true -Description "Security group for members of the $($user.Department) department."
            Add-AzureADGroupMember -ObjectId $group.ObjectID -RefObjectId $newUser.ObjectID
            Write-Host " -> Created group: $($group.DisplayName)"
            "  -> Added to group: $($group.DisplayName)"
            "  -> Adding to group: $($group.DisplayName)... SUCCESS" | Out-File -Append -FilePath $logPath
        }
    }
    
Write-Host "✅ Provisioning complete."
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Provisioning complete. Total users processed: $($users.Count)" | Out-File -Append -FilePath $logPath
}