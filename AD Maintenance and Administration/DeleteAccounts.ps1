<#
.SYNOPSIS
    Deletes specified accounts based on a CSV file input.

.DESCRIPTION
    This script deletes user accounts listed in a CSV file. The CSV file should be in the same directory as the script and must contain a header named 'AccountName' followed by the account names to be deleted. Upon completion, the script generates a log file detailing the actions taken and any errors encountered.

.PARAMETER CsvPath
    Specifies the path to the CSV file containing the account names to be deleted. If not provided, the script defaults to a CSV file named 'DeleteAccounts.csv' in the same directory as the script.

.EXAMPLE
    .\Delete-Accounts.ps1 -CsvPath "C:\Path\To\DeleteAccounts.csv"
    This command runs the script and deletes accounts listed in the specified CSV file.

.EXAMPLE
    .\Delete-Accounts.ps1
    This command runs the script and deletes accounts listed in the 'DeleteAccounts.csv' file located in the same directory as the script.

.INPUTS
    A csv file is needed as an input with the following header : AccountName

.OUTPUTS
    This script does not produce any output to the pipeline. It generates a log file in the script's directory.

.NOTES
    - Ensure you have the necessary permissions to delete accounts in Active Directory.
    - Review the CSV file for accuracy before running the script to prevent accidental deletions.

.REQUIREMENTS
    - Windows PowerShell 5.1 or later.
    - Active Directory module for PowerShell.

.VERSION
    1.1

.AUTHOR
    Owen L.

.LICENSE
    This script is licensed under the MIT License. Use it responsibly and ensure compliance with your organization's policies.
#>

# Function to check if a user exists in Active Directory
function Check-User {
    param (
        [Parameter(Mandatory=$true)]
        [string]$User
    )
    try {
        Get-ADUser -Identity $User -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    } 
}

# Function to get the directory where the script is stored
function Get-ScriptDirectory {
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
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

# Define parameters
param (
    [string]$CsvPath = "$(Get-ScriptDirectory)\DeleteAccounts.csv"
)

# Initialize variables
$MyPath = Get-ScriptDirectory
$MyScriptName = "DeleteAccounts"
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

# Import the CSV file and process each account
Import-Csv -Path $CsvPath -Delimiter ";" | ForEach-Object {
    $samaccountname = $_.AccountName

    Write-Host "----------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "Start Deleting User Account $samaccountname" -ForegroundColor Yellow
    Log "Start Deleting User Account $samaccountname" "INFO"

    if (Check-User -User $samaccountname) {
        try {
            Write-Host "The user account $samaccountname exists"
            Log "The user account $samaccountname exists" "INFO"
            Remove-ADUser -Identity $samaccountname -Confirm:$false
            Write-Host "Account deleted: $samaccountname" -ForegroundColor Green
            Log "Account deleted: $samaccountname" "INFO"
        }
        catch {
            Write-Host "Error Deleting User Account $samaccountname - $($_.Exception.Message)" -ForegroundColor Red
            Log "Error Deleting User Account $samaccountname - $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Host "Account not found in the domain: $samaccountname" -ForegroundColor Red
        Log "Account not found in the domain: $samaccountname" "ERROR"
    }
}

# Calculate and log script completion time
$elapsed = (Get-Date) - $startTime
Write-Host "Script completion time: $elapsed" -ForegroundColor Yellow
Log "Script completion time: $elapsed" "INFO"
