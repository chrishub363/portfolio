# ==============================================================================
#  Find-Sophos.ps1
#
#  Generates a list of computers
#    indicates whether computers have Sophos installed or not
#
#  Chris :: 12/14/2012 @ 8:30 AM
# ==============================================================================

Param([switch]$File)

# Load Microsoft AD Tools
Import-Module ActiveDirectory 

$DateStamp = Get-Date -uformat "%Y.%m.%d @ %H%M%S"
$ExportPath = "$Home\Desktop\$DateStamp"

Write-Host ""
If ($File) {
  $ComputerCollection = @()
  $ImportFile = Read-Host "Enter the path to the file you'd like to import"
  $Import = Import-CSV $ImportFile
  ForEach ($Item in $Import) {
    $ComputerName = $Item.Name
    $ComputerCollection += Get-ADComputer -Filter {Name -like $ComputerName}
	}
} Else {
  $ComputerCollection = Get-ADComputer -Filter {OperatingSystem -ne "Mac OS X"} -ResultSetSize $NULL
}

$64bit = "C$\Program Files (x86)"
$32bit = "C$\Program Files"

# Some collections to store our results
$SophosHappy = @()
$SophosSad = @()
$NoSophos = @()
$NoResponse = @()
$NoPrograms = @()

$Update = Read-Host "Enter the exact name of a recent update file"
Write-Host "Querying computers to see if they have Sophos installed and up-to-date..." -ForeGroundColor Cyan

ForEach ($Computer in $ComputerCollection) {
  $Count++
  Write-Progress -Activity "Querying Computers..." -Status "Percent Complete:" -PercentComplete (($Count / $ComputerCollection.Count) * 100)
  $ComputerName = $Computer.Name
  Write-Host "  Querying $ComputerName ... " -NoNewLine
  If (Test-Connection -Source localhost -ComputerName $ComputerName -Quiet) {
    If (Test-Path "\\$ComputerName\$64bit") {
      # looks like we've got a 64-bit machine
      $Path = "\\$ComputerName\$64bit\Sophos\Sophos Anti-Virus"
		} ElseIf (Test-Path "\\$ComputerName\$32bit") {
      # looks like we've got a 32-bit machine
      $Path = "\\$ComputerName\$32bit\Sophos\Sophos Anti-Virus"
		} Else {
      # looks like we've got an error
      $Path = "-ERR-"
		}
	} Else {
    # no response from the machine
    $Path = "-NOR-"
	}
  
  If ($Path -eq "-ERR-") {
    # report and log the error
    Write-Host "Can't find %ProgramFiles%" -ForeGroundColor Red
    $NoPrograms += $Computer
	} ElseIf ($Path -eq "-NOR-") {
    # report and log the error
    Write-Host "No Response" -ForeGroundColor Red
    $NoResponse += $Computer
	} ElseIf (Test-Path "$Path\SavMain.exe") {
    # looks like Sophos is installed
    If (Test-Path "$Path\$Update") {
      # looks like Sophos is reasonably up-to-date
      Write-Host "Sophos is installed and up to date" -ForeGroundColor Green
      $SophosHappy += $Computer
		} Else {
      # looks like Sophos is out of date
      Write-Host "Sophos is installed, but out of date" -ForeGroundColor Yellow
      $SophosSad += $Computer
		}
	} Else {
    # looks like Sophos is NOT installed
    Write-Host "Sophos is not installed" -ForeGroundColor Red
    $NoSophos += $Computer
	}
}
Write-Host "...operation complete." -ForeGroundColor Cyan

Write-Host ""
Write-Host "Exporting data to the Desktop..." -ForeGroundColor Cyan
If (!(Test-Path $ExportPath)) {New-Item $ExportPath -Type Directory | Out-Null}
$SophosHappy | Select-Object Name | Sort-Object Name | Export-CSV "$ExportPath\SophosHappy.csv" -NoTypeInformation
$SophosSad | Select-Object Name | Sort-Object Name | Export-CSV "$ExportPath\SophosSad.csv" -NoTypeInformation
$NoSophos | Select-Object Name | Sort-Object Name | Export-CSV "$ExportPath\NoSophos.csv" -NoTypeInformation
$NoPrograms | Select-Object Name | Sort-Object Name | Export-CSV "$ExportPath\NoPrograms.csv" -NoTypeInformation
$NoResponse | Select-Object Name | Sort-Object Name | Export-CSV "$ExportPath\NoResponse.csv" -NoTypeInformation
Write-Host "...export complete." -ForeGroundColor Cyan
Write-Host ""
