Function Update-Distro {
<#
  .DESCRIPTION
    Bulk update for distribution lists
    Avoids limitations of Update-DistributionGroupMember for really large updates
  .PARAMETER File
    Path to the input file - must be a line-separated list of email addresses
  .PARAMETER List
    The distribution list to update 
  .PARAMETER Overwrite
    The specified file will completely overwrite existing group membership
  .EXAMPLE
    Update-Distro -File "..\Downloads\SomeFile.txt" -List "distro@somewhere.net" -Overwrite
#>

  Param([Parameter(Mandatory=$true)]$File,
        [Parameter(Mandatory=$true)]$List,
        [Parameter(Mandatory=$false)][Switch]$Overwrite)
  
  $Members = Get-Content -Path $File
  $OriginalTitle = $host.UI.RawUI.WindowTitle

  Write-Host ""

  If ($Overwrite) {
    Write-Host "[$(Get-Date -format s)] Purging $List"
    $Members | Select -First 1 | %{Update-DistributionGroupmember -Identity $List -Members $_ -Confirm:$false}
    $Members | Select -First 1 | %{Remove-DistributionGroupmember -Identity $List -Member $_ -Confirm:$false}
  }

  $Counter = 0
  Write-Host "[$(Get-Date -format s)] Updating $List"
  ForEach ($Item in $Members) {
    $Counter++
    $Address = $Item.Trim()
    $Percent = [Math]::Round(($Counter / $Members.Count) * 100)
    Write-Progress -Activity "updating $List" -Status "($Counter/$($Members.Count)): $Address" -PercentComplete $Percent
    $host.UI.RawUI.WindowTitle = "$Percent%"

    $Member = $null; $Member = Get-Recipient $Address | Where {$_.PrimarySmtpAddress -like "$Address"}
    If ($Member) {
      Add-DistributionGroupMember -Identity $List -Member $Member.GUID -BypassSecurityGroupManagerCheck | Out-Null
    } Else {
      Write-Host "    lookup failed:  $Address"
    }
  }
  $host.UI.RawUI.WindowTitle = $OriginalTitle
  $DistroCount = Get-DistributionGroupMember -Identity $List -Resultsize unlimited | Measure-Object | Select -ExpandProperty Count
  $MemberCount = $Members.Count

  Write-Host "[$(Get-Date -format s)] Update completed"
  Write-Host "    input file:  $MemberCount"
  Write-Host "    distro count:  $DistroCount"
  Write-Host ""

}