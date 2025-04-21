<#
.SYNOPSIS
Creates a nicely-organized/packaged export of all Group Policy Objects

.DESCRIPTION
Creates a timestamped export of all Group Policy Objects, with an HTML report for each GPO.

.PARAMETER Path
Specifies the path to the backup.
If this location does not exist, it will be created.
Defaults to the location of the script.

.PARAMETER Domain
Specifies the domain to export Group Policy Objects from.
Defaults to the domain of the user running the script.

.EXAMPLE
.\Backup-GroupPolicy.ps1
Creates a backup of all Group Policy Objects in the user's domain in the same folder as the script.

.EXAMPLE
.\Backup-GroupPolicy.ps1 -Path E:\GPOBackup
Creates a backup of all Group Policy Objects in the user's domain in E:\GPOBackup\

.EXAMPLE
.\Backup-GroupPolicy.ps1 -Path E:\GPOBackup -Domain example.com
Creates a backup of all Group Policy Objects in the example.com domain in E:\GPOBackup\


#>


Param([string]$Path = $PSScriptRoot,
      [string]$Domain = $ENV:UserDNSDomain)


$MaxRetries = 5
$SleepTime = 10
$DateStamp = (Get-Date -Format s).Replace(":",".")
If (!$Path) { $Path = Split-Path $MyInvocation.MyCommand.Path -Parent }
If ($Path[$Path.Length-1] -ne "\") { $Path = $Path + "\" }
$BasePath = $Path + $Domain + "\"
$Path = $Path + $Domain + "\" + $DateStamp + "\"
$LogFile = "$Path" + "Export-GroupPolicy.log"
Try {
  New-Item -Path $Path -Type Directory -ErrorAction Stop | Out-Null
} Catch {
  Write-Host "Encountered errors writing to... " -ForeGroundColor Red
  Write-Host "    $Path" -ForeGroundColor White
  Write-Host "Please verify the path and ensure you have permission to write to that location." -ForeGroundColor Red
  Exit 1
} 


Import-Module GroupPolicy


Write-Host ""
"$(Get-Date):  Auditing Inheritance Blocking in $Domain" | %{ Write-Host $_; Out-File -FilePath $LogFile -InputObject $_ -Append }

$OUs = ([adsisearcher]"objectclass=organizationalunit")
$OUs.PropertiesToLoad.AddRange("DistinguishedName")
$OUs.FindAll().Properties.distinguishedname | %{
  "    Block: {0,-5}  {1}  " -f $(Get-GPInheritance $_ | Select -ExpandProperty GpoInheritanceBlocked),$_ | %{ Out-File -FilePath $LogFile -InputObject $_ -Append}
}


"$(Get-Date):  Exporting GPOs from $Domain to $Path" | %{ Write-Host $_; Out-File -FilePath $LogFile -InputObject $_ -Append }

$PolicyCollection = Get-GPO -All -Domain $Domain -Server $Domain | Sort-Object -Property DisplayName

$ProgressCounter = 0
ForEach ($Policy in $PolicyCollection) {
  $ProgressCounter++
  $PolicyName = $Policy.DisplayName
  $PolicyName = [RegEx]::Replace($PolicyName, "[{0}]" -f ([RegEx]::Escape([String][System.IO.Path]::GetInvalidFileNameChars())), '')
  $ExportPath = $Path + $PolicyName
  Write-Progress -Activity "Exporting Group Policy Objects..." -Status $PolicyName -PercentComplete ($ProgressCounter / $PolicyCollection.Count * 100)

  $Success = $False
  $RetryCounter = 0
  Do{
    $RetryCounter++

    Try {
      New-Item -Path $ExportPath -Type Directory -ErrorAction Stop | Out-Null
      $Success = $True
    } Catch {
      "$(Get-Date):    [$RetryCounter][PathCreate]$($Policy.DisplayName):  $($Error[0].Exception.Message)  " | %{ Write-Host $_; Out-File -FilePath $LogFile -InputObject $_ -Append }
      Write-Progress -Activity "Exporting Group Policy Objects..." -Status "Retrying[$RetryCounter]... $PolicyName" -PercentComplete ($ProgressCounter / $PolicyCollection.Count * 100)
      Start-Sleep -Seconds $SleepTime
    } 
  } Until ($Success -or ($RetryCounter -ge $MaxRetries))

  $Success = $False
  $RetryCounter = 0
  Do{
    $RetryCounter++
    Try {
      $Policy | Get-GPOReport -Path "$ExportPath\$PolicyName.html" -Domain $Domain -ReportType HTML -Server $Domain -ErrorAction Stop | Out-Null
      $Success = $True
    } Catch {
      "$(Get-Date):    [$RetryCounter][ReportHTML]$($Policy.DisplayName):  $($Error[0].Exception.Message)  " | %{ Write-Host $_; Out-File -FilePath $LogFile -InputObject $_ -Append }
      Write-Progress -Activity "Exporting Group Policy Objects..." -Status "Retrying[$RetryCounter]... $PolicyName" -PercentComplete ($ProgressCounter / $PolicyCollection.Count * 100)
      Start-Sleep -Seconds $SleepTime
    } 
  } Until ($Success -or ($RetryCounter -ge $MaxRetries))

  $Success = $False
  $RetryCounter = 0
  Do{
    $RetryCounter++
    Try {
      $Policy | Get-GPOReport -Path "$ExportPath\$PolicyName.xml" -Domain $Domain -ReportType XML -Server $Domain -ErrorAction Stop | Out-Null
      $Success = $True
    } Catch {
      "$(Get-Date):    [$RetryCounter][ReportXML]$($Policy.DisplayName):  $($Error[0].Exception.Message)  " | %{ Write-Host $_; Out-File -FilePath $LogFile -InputObject $_ -Append }
      Write-Progress -Activity "Exporting Group Policy Objects..." -Status "Retrying[$RetryCounter]... $PolicyName" -PercentComplete ($ProgressCounter / $PolicyCollection.Count * 100)
      Start-Sleep -Seconds $SleepTime
    } 
  } Until ($Success -or ($RetryCounter -ge $MaxRetries))

  $Success = $False
  $RetryCounter = 0
  Do{
    $RetryCounter++
    Try {
      $Policy | Backup-GPO -Path $ExportPath -Domain $Domain -Comment "export created on $DateStamp" -Server $Domain -ErrorAction Stop | Out-Null
      $Success = $True
    } Catch {
      "$(Get-Date):    [$RetryCounter][Backup]$($Policy.DisplayName):  $($Error[0].Exception.Message)  " | %{ Write-Host $_; Out-File -FilePath $LogFile -InputObject $_ -Append }
      Write-Progress -Activity "Exporting Group Policy Objects..." -Status "Retrying[$RetryCounter]... $PolicyName" -PercentComplete ($ProgressCounter / $PolicyCollection.Count * 100)
      Start-Sleep -Seconds $SleepTime
    } 
  } Until ($Success -or ($RetryCounter -ge $MaxRetries))
}

Remove-Module GroupPolicy

Compress-Archive -Path "$Path\*" -DestinationPath "$BasePath\$DateStamp.zip"

"$(Get-Date):  Done exporting GPOs from $Domain to $Path" | %{ Write-Host $_; Out-File -FilePath $LogFile -InputObject $_ -Append }
Write-Host ""


