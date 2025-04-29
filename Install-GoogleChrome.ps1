<#	
  .NOTES
    ===========================================================================
    Created on:   	12/8/2017
    Created by:   	Chris
    Organization: 	
    Filename:      GoogleChrome.ps1
    ===========================================================================
  .DESCRIPTION
    Script for installing and removing Google Chrome with SCCM
  .PARAMETER UnInstall
    Switch parameter, used to removed Google Chrome entirely
  .EXAMPLE
    GoogleChrome.ps1
    Installs the latest supported version of Google Chrome
  .EXAMPLE
    GoogleChrome.ps1 -UnInstall
    Removes Google Chrome
#>

Param ([switch]$UnInstall)


Function Remove-GoogleChrome
{
  <#
    .DESCRIPTION
      Completely removes all instances of Google Chrome on the machine
  #>

  $AppInfo = Get-WmiObject Win32_Product -Filter "Name Like 'Google Chrome'"
  If ($AppInfo) {& ${env:WINDIR}\System32\msiexec /x $AppInfo.IdentifyingNumber /Quiet /Passive /NoRestart}
  $Reg32Key = Get-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome" -name "Version" -ErrorAction SilentlyContinue
  $Ver32Path = $Reg32Key.Version
  If ($Ver32Path) {& ${env:ProgramFiles}\Google\Chrome\Application\$Ver32Path\Installer\setup.exe --uninstall --multi-install --chrome --system-level --force-uninstall}
  $Reg64Key = Get-ItemProperty -path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome' -name "Version" -ErrorAction SilentlyContinue
  $Ver64Path = $Reg64Key.Version
  If ($Ver64Path) {& ${env:ProgramFiles(x86)}\Google\Chrome\Application\$Ver64Path\Installer\setup.exe --uninstall --multi-install --chrome --system-level --force-uninstall}
}

$MachineTemp = [environment]::GetEnvironmentVariable("temp","machine")
$ScriptName = ($MyInvocation.MyCommand.Name).Split('.')[0]
$LogFile = "$MachineTemp\$ScriptName.log"
$ComputerName = $env:ComputerName
$OSCaption = Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption
$OSArchitecture = Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty OSArchitecture
$UserName = $env:UserName
$IPAddress = Get-NetIPAddress -AddressState Preferred -AddressFamily IPv4 | Where {($_.InterfaceAlias -like "Ethernet") -or ($_.InterfaceAlias -like "Wi-Fi")} | Select-Object -ExpandProperty IPAddress
$Domain = (Get-WmiObject Win32_ComputerSystem).Domain

"===========================================================================" | %{Out-File -FilePath $LogFile -InputObject $_ -Append}
"Computer Name:  $ComputerName" | %{Out-File -FilePath $LogFile -InputObject $_ -Append}
"Operating System:  $OSCaption $OSArchitecture" | %{Out-File -FilePath $LogFile -InputObject $_ -Append}
"Current User:  $UserName" | %{Out-File -FilePath $LogFile -InputObject $_ -Append}
"IP Address:  $IPAddress" | %{Out-File -FilePath $LogFile -InputObject $_ -Append}
"Domain:  $Domain" | %{Out-File -FilePath $LogFile -InputObject $_ -Append}
"Execution Time:  $(Get-Date)" | %{Out-File -FilePath $LogFile -InputObject $_ -Append}
"===========================================================================" | %{Out-File -FilePath $LogFile -InputObject $_ -Append}


<#
If ($UnInstall) {
  Remove-GoogleChrome
} Else {
  Remove-GoogleChrome
  & ${env:WINDIR}\System32\msiexec /i "$PSScriptRoot\googlechromestandaloneenterprise64.msi" /q
}
#>