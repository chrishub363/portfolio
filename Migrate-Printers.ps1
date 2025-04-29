<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2014 v4.1.57
	 Created on:   	6/11/2014 8:54 AM
	 Created by:   	Chris
	 Organization: 	
	 Filename:     	Migrate-Printers.ps1
	===========================================================================
	.DESCRIPTION
		Logon Script to migrate printer mappings
  .SYNOPSIS
    Logon Script to migrate printer mappings
  .PARAMETER oldPrintServer
    The name of the old print server
  .PARAMETER newPrintServer
    The name of the new print server
  .PARAMETER PrinterLog
    The full path to where the log file should be written
    Defaults to C:\Windows\Temp
  .PARAMETER Purge
    If the -Purge parameter is specified, printers missing from the newPrintServer will be removed
  .EXAMPLE
    .\Migrate-Printers.ps1 -oldPrintServer "prntsrv.somewhere.local" -newPrintServer "printers.somewhere.local"
    Removes any printers mapped to "prntsrv.somewhere.local" and replaces them with mappings to "printers.somewhere.local"
    Logs actions to C:\Windows\Temp\PrintMig YYYY-MM-DD.csv
  .EXAMPLE
    .\Migrate-Printers.ps1 -oldPrintServer "prntsrv.somewhere.local" -newPrintServer "printers.somewhere.local" -PrinterLog "\\server\migration"
    Removes any printers mapped to "prntsrv.somewhere.local" and replaces them with mappings to "printers.somewhere.local"
    Logs actions to \\server\migration\PrintMig YYYY-MM-DD.csv
  .EXAMPLE
    .\Migrate-Printers.ps1 -oldPrintServer "prntsrv.somewhere.local" -newPrintServer "printers.somewhere.local" -PrinterLog "\\server\migration" -Purge
    Removes any printers mapped to "prntsrv.somewhere.local" and replaces them with mappings to "printers.somewhere.local"
    Logs actions to \\server\migration\PrintMig YYYY-MM-DD.csv
    Removes any printers missing from "printers.somewhere.local"
#>


Param (
  [string]$oldPrintServer = "server1.somewhere.local",
  [string]$newPrintServer = "server2.somewhere.local",
  [string]$PrinterLog = "$([Environment]::GetEnvironmentVariable("temp", "machine"))",
  [switch]$Purge
)


$LogFile = "$PrinterLog\PrintMig $(Get-Date -Format yyyy-MM-dd).csv"


If (-not (Test-Path $LogFile)) {
  "COMPUTERNAME,USERNAME,PRINTERNAME,RETURNCODE-ERRORMESSAGE,DATETIME,STATUS" | Out-File -FilePath $LogFile -Encoding ASCII
}


Try {
  Write-Verbose ("{0}: Checking for printers mapped to old print server" -f $ENV:USERNAME)
  $Printers = @(Get-WmiObject -Class Win32_Printer -Filter "SystemName='\\\\$oldPrintServer'" -ErrorAction Stop)
  
  If ($Printers.Count -gt 0) {
    ForEach ($Printer in $Printers) {
      Write-Verbose ("{0}: Replacing with new print server name: {1}" -f $Printer.Name, $newPrintServer)
      $newPrinter = $Printer.Name -replace $oldPrintServer, $newPrintServer
      $returnValue = ([wmiclass]"Win32_Printer").AddPrinterConnection($newPrinter).ReturnValue
      If ($returnValue -eq 0) {
        "{0},{1},{2},{3},{4},{5}" -f $ENV:COMPUTERNAME, $ENV:USERNAME, $newPrinter, $returnValue, (Get-Date), "Added Printer" | Out-File -FilePath $LogFile -Append -Encoding ASCII
        If ($Printer.Default) {
          Write-Verbose ("{0}: Setting Default Printer" -f $Printer.Name)
          $newDefaultPrinter = Get-WmiObject -Class Win32_Printer -Filter "Name='$(($newPrinter).Replace("\","\\"))'"
          $returnValue = $newDefaultPrinter.SetDefaultPrinter().ReturnValue
          If ($returnValue -eq 0) {
            "{0},{1},{2},{3},{4},{5}" -f $ENV:COMPUTERNAME, $ENV:USERNAME, $newPrinter, $returnValue, (Get-Date), "Set Default Printer" | Out-File -FilePath $LogFile -Append -Encoding ASCII
          } Else {
            Write-Verbose ("{0} returned error code: {1}" -f $newPrinter, $returnValue) -Verbose
            "{0},{1},{2},{3},{4},{5}" -f $ENV:COMPUTERNAME, $ENV:USERNAME, $newPrinter, $returnValue, (Get-Date), "Error Setting Default Printer" | Out-File -FilePath $LogFile -Append -Encoding ASCII
          }
        }
        Write-Verbose ("{0}: Removing" -f $Printer.Name)
        $Printer.Delete()
        "{0},{1},{2},{3},{4},{5}" -f $ENV:COMPUTERNAME, $ENV:USERNAME, $Printer.Name, $returnValue, (Get-Date), "Removed Printer" | Out-File -FilePath $LogFile -Append -Encoding ASCII
      } ElseIf ($Purge -and ($returnValue -eq 1801)) {
        Write-Verbose ("{0} not found, purging {1}" -f $newPrinter, $Printer.Name) -Verbose
        "{0},{1},{2},{3},{4},{5}" -f $ENV:COMPUTERNAME, $ENV:USERNAME, $newPrinter, $returnValue, (Get-Date), "Printer Not Found" | Out-File -FilePath $LogFile -Append -Encoding ASCII
        $Printer.Delete()
        "{0},{1},{2},{3},{4},{5}" -f $ENV:COMPUTERNAME, $ENV:USERNAME, $Printer.Name, $returnValue, (Get-Date), "Purged Printer" | Out-File -FilePath $LogFile -Append -Encoding ASCII
      } Else {
        Write-Verbose ("{0} returned error code: {1}" -f $newPrinter, $returnValue) -Verbose
        "{0},{1},{2},{3},{4},{5}" -f $ENV:COMPUTERNAME, $ENV:USERNAME, $newPrinter, $returnValue, (Get-Date), "Error Adding Printer" | Out-File -FilePath $LogFile -Append -Encoding ASCII
      }
    }
  }
} Catch {
  "{0},{1},{2},{3},{4},{5}" -f $ENV:COMPUTERNAME, $ENV:USERNAME, "WMIERROR", $_.Exception.Message, (Get-Date), "Error Querying Printers" | Out-File -FilePath $LogFile -Append -Encoding ASCII
}


