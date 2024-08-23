<#
.SYNOPSIS
    Creates Active Directory groups

.DESCRIPTION
    This script is used to create groups in Active Directory based on information provided in a CSV file.

.PARAMETER CsvPath
    Specifies the path to the CSV file containing the following headers 'GroupName;Description;OU;GroupScope;GroupCategory;mail' and the group details. If not provided, the script defaults to a CSV file named 'GroupsCreation.csv' in the same directory as the script.

.EXAMPLE
    .\Create-ADGroups.ps1 -CsvPath "C:\Path\To\GroupsCreation.csv"
    This command runs the script and creates groups based on the information in the specified CSV file.

.EXAMPLE
    .\Create-ADGroups.ps1
    This command runs the script and creates groups based on the information in the 'GroupsCreation.csv' file located in the same directory as the script.

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    It generates a log file in the script's directory and a csv file with the data retrieved.

.NOTES
    - Ensure you have the necessary permissions to create groups in Active Directory.
    - Review the CSV file for accuracy before running the script to prevent accidental group creations.

.VERSION
    2.1

.AUTHOR
    Drackk

.LICENSE
    This script is licensed under the MIT License. Use it responsibly and ensure compliance with your organization's policies.
#>

Import-Module ActiveDirectory

# Function to check if a group exists in Active Directory
function Check-Group {
    param (
        [Parameter(Mandatory=$true)]
        [string]$GroupToCheck
    )
    try {
        Get-ADGroup -Identity $GroupToCheck -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Function to check if an organizational unit (OU) exists in Active Directory
function Check-OU {
    param (
        [Parameter(Mandatory=$true)]
        [string]$OUToCheck
    )
    try {
        Get-ADOrganizationalUnit -Identity $OUToCheck -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Function to log messages with a timestamp and log level
function Log {
    param (
        [Parameter(Mandatory=$true)] 
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] $Message"
    Add-Content -Path $MyDebugFile -Value $logMessage
}

# Function to get the directory where the script is stored
function Get-ScriptDirectory {
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

# Define parameters
param (
    [string]$CsvPath = "$(Get-ScriptDirectory)\GroupsCreation.csv"
)

# Initialize variables
$MyPath = Get-ScriptDirectory
$MyScriptName = "GroupsCreation"
$MyDate = Get-Date -Format 'yyyyMMdd.HHmmss'
$MyDebugFile = "$MyPath\$MyScriptName.$((Get-ADDomain).NetBIOSName).$MyDate.Log"
$startTime = Get-Date

# Start logging
Log "Script $MyScriptName started" "INFO"
Write-Host "Script $MyScriptName started" -ForegroundColor Yellow

# Check if the CSV file exists
if (-Not (Test-Path -Path $CsvPath)) {
    Write-Host "CSV file not found at $CsvPath" -ForegroundColor Red
    Log "CSV file not found at $CsvPath" "ERROR"
    exit 1
}

# Import the CSV file and process each group
Import-Csv -Path $CsvPath -Delimiter ";" | ForEach-Object {
    $groupName = $_.GroupName
    $description = $_.Description
    $targetOU = $_.OU
    $groupScope = $_.GroupScope
    $groupCategory = $_.GroupCategory
    $mail = $_.mail

    Write-Host "----------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "Start Creating Group $groupName" -ForegroundColor Yellow
    Log "Start Creating Group $groupName" "INFO"
    
    if (Check-Group -GroupToCheck $groupName) {
        Write-Host "Group $groupName already exists" -ForegroundColor Yellow
        Log "Group $groupName already exists" "WARNING"
    } else {
        if (Check-OU -OUToCheck $targetOU) {
            try {
                New-ADGroup -Name $groupName -SamAccountName $groupName -Path $targetOU -GroupScope $groupScope -GroupCategory $groupCategory -Description $description -OtherAttributes @{'mail' = $mail}
                Write-Host "Successfully created group $groupName" -ForegroundColor Green
                Log "Successfully created group $groupName" "INFO"
            }
            catch {
                Write-Host "Error creating group $groupName - $($_.Exception.Message)" -ForegroundColor Red
                Log "Error creating group $groupName - $($_.Exception.Message)" "ERROR"
            }
        } else {
            Write-Host "The OU $targetOU is incorrect" -ForegroundColor Red
            Log "The OU $targetOU is incorrect" "ERROR"
        }
    }

    Write-Host "----------------------------------------------------------" -ForegroundColor Yellow
    Log "----------------------------------------------------------" "INFO"
}

# Calculate and log script completion time
$elapsed = (Get-Date) - $startTime
Write-Host "Script completion time: $elapsed" -ForegroundColor Yellow
Log "Script completion time: $elapsed" "INFO"
