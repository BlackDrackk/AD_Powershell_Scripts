<#
.SYNOPSIS
    Creates Active Directory Accounts.

.DESCRIPTION
    This script is used to create accounts and add them to a group based on information provided in a CSV file. The CSV file should be in the same directory as the script and must contain headers named 'ID;Description;OU;Group' followed by the corresponding information. Upon completion, the script generates a log file detailing the actions taken and any errors encountered.If an account

.PARAMETER CsvPath
    Specifies the path to the CSV file containing the accounts details. If not provided, the script defaults to a CSV file named 'CreateAccounts.csv' in the same directory as the script.

.EXAMPLE
    .\CreateAccounts.ps1 -CsvPath "C:\Path\To\CreateAccounts.csv"
    This command runs the script and creates accounts based on the information in the specified CSV file.

.EXAMPLE
    .\CreateAccounts.ps1
    This command runs the script and creates accounts based on the information in the 'CreateAccounts.csv' file located in the same directory as the script.

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    It generates a log file in the script's directory and a csv file with all the info retreived 

.NOTES
    - Ensure you have the necessary permissions to create accounts in Active Directory.
    - Review the CSV file for accuracy before running the script to prevent accidental account creation.

.REQUIREMENTS
    - Active Directory module for PowerShell.

.VERSION
    2.2

.AUTHOR
    Drackk

.LICENSE
    This script is licensed under the MIT License. Use it responsibly and ensure compliance with your organization's policies.
#>

param (
    [string]$CsvPath = "$(Get-ScriptDirectory)\CreateAccounts.csv"
)

Import-Module ActiveDirectory


$domUPN = (Get-ADDomain).DNSRoot
$domNETBIOS = (Get-ADDomain).NetbiosName

Function PasswordGenerator {
#Put your own PasswordGenerator
}

Function Get-ScriptDirectory {
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

Function Log {
    Param (
        [parameter(Mandatory = $true)] 
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] $Message"
    Add-Content -Path $MyDebugFile -Value $logMessage
}

Function CheckAccountInGroup {
    param (
        [string]$accountName,
        [string]$groupName
    )
    try {
        $members = Get-ADGroupMember -Identity $groupName
        foreach ($member in $members) {
            if ($member.samaccountname -eq $accountName) {
                Write-Host "$accountName is already a member of $groupName" -ForegroundColor Yellow
                return $true
            }
        }
    } catch {
        Write-Host "Unable to verify if $accountName is a member of $groupName - $($_.Exception.Message)" -ForegroundColor Yellow
    }
    return $false
}

Function CheckGroup {
    param ($GroupToCheck)
    try {
        Get-ADGroup -Identity $GroupToCheck -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

Function CheckUser {
    param ($AccountToCheck)
    try {
        Get-ADUser -Identity $AccountToCheck -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

Function CheckOU {
    param ($OUToCheck)
    try {
        Get-ADOrganizationalUnit -Identity $OUToCheck -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

Function CreateUserAccount {
    param (
        [string]$samaccountname,
        [string]$sn,
        [string]$givenname,
        [string]$displayname,
        [string]$upn,
        [string]$Description,
        [string]$targetOU
    )
    try {
        $initialpassword = PasswordGenerator
        $setpass = ConvertTo-SecureString -AsPlainText $initialpassword -Force
        New-ADUser -Name $samaccountname -SamAccountName $samaccountname -Surname $sn -GivenName $givenname -DisplayName $displayname -Description $Description -UserPrincipalName $upn -Path $targetOU -AccountPassword $setpass -ChangePasswordAtLogon $false -Enabled $true -ErrorAction Stop
        Write-Host "Successfully created user account $samaccountname" -ForegroundColor Green
        Log "Successfully created user account $samaccountname" "INFO"
    } catch {
        Write-Host "Error creating user account $samaccountname - $($_.Exception.Message)" -ForegroundColor Red
        Log "Error creating user account $samaccountname - $($_.Exception.Message)" "ERROR"
    }
}

$MyPath = Get-ScriptDirectory
Set-Location $MyPath

$MyScriptName = "CreateAccounts"
$MyDate = '{0:yyyyMMdd.HHmmss}' -f (Get-Date)
$MyDebugFile = "$MyPath\$($MyScriptName).$($domNETBIOS).$($MyDate).Log"

$startTime = Get-Date

Log "Script $MyScriptName started" "INFO"
Write-Host "Script $MyScriptName started" -ForegroundColor Yellow

Import-Csv -Path $CsvPath -Delimiter ";" | ForEach-Object {
    $samaccountname = $_.ID
    $sn = $_.ID
    $givenname = $_.ID
    $displayname = $_.ID
    $upn = "$samaccountname@$domUPN"
    $Description = $_.Description
    $targetOU = $_.OU
    $Group = $_.Group

    Write-Host "----------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "Start creating user account $samaccountname" -ForegroundColor Yellow
    Log "Start creating user account $samaccountname" "INFO"
    
    if (CheckUser $samaccountname) {
        Write-Host "Account $samaccountname already exists" -ForegroundColor Yellow
        Log "Account $samaccountname already exists" "WARNING"
        
        $user = Get-ADUser -Identity $samaccountname -Properties Enabled
        if (-not $user.Enabled) {
            Write-Host "Account $samaccountname is disabled. Recreating..." -ForegroundColor Yellow
            Log "Account $samaccountname is disabled. Recreating..." "WARNING"
            Remove-ADUser -Identity $samaccountname -Confirm:$false
            CreateUserAccount -samaccountname $samaccountname -sn $sn -givenname $givenname -displayname $displayname -upn $upn -Description $Description -targetOU $targetOU
        }
    } else {
        if (CheckOU $targetOU) {
            CreateUserAccount -samaccountname $samaccountname -sn $sn -givenname $givenname -displayname $displayname -upn $upn -Description $Description -targetOU $targetOU
        } else {
            Write-Host "The $targetOU is incorrect" -ForegroundColor Red
            Log "The $targetOU is incorrect" "ERROR"
        }
    }

    if ($Group -and (CheckGroup $Group)) {
        if (-not (CheckAccountInGroup -accountName $samaccountname -groupName $Group)) {
            try {
                Add-ADGroupMember -Identity $Group -Members $samaccountname
                Write-Host "Added $samaccountname to group $Group" -ForegroundColor Green
                Log "Added $samaccountname to group $Group" "INFO"
            } catch {
                Write-Host "Error adding $samaccountname to group $Group - $($_.Exception.Message)" -ForegroundColor Red
                Log "Error adding $samaccountname to group $Group - $($_.Exception.Message)" "ERROR"
            }
        }
    } else {
        Write-Host "Group $Group does not exist" -ForegroundColor Red
        Log "Group $Group does not exist" "ERROR"
    }

    Write-Host "----------------------------------------------------------" -ForegroundColor Yellow
    Log "----------------------------------------------------------" "INFO"
}

$elapsed = (Get-Date) - $startTime
Write-Host "Script completion time: $elapsed" -ForegroundColor Yellow
Log "Script completion time: $elapsed" "INFO"
