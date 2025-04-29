Function Find-Recipient {
<#
  .DESCRIPTION
    Builds a Get-Recipient filter
  .PARAMETER SearchString
    Specifies the words you want to search for with Get-Recipient
  .PARAMETER Output
    Specifies how you want the output displayed
    Options are List, Table, or Grid
    Defaults to List
  .EXAMPLE
    Find-Recipient "la de dah"
      ...translates into...
    Get-Recipient -Filter {((DisplayName -like "*la*") -and (DisplayName -like "*de*") -and (DisplayName -like "*dah*")) 
      -or ((PrimarySmtpAddress -like "*la*") -and (PrimarySmtpAddress -like "*de*") -and (PrimarySmtpAddress -like "*dah*"))} 
      | Select DisplayName,PrimarySmtpAddress,RecipientTypeDetails | Sort DisplayName | FL
#>

  Param([Parameter(Mandatory=$true)]$SearchString,
        [Parameter(Mandatory=$false)][ValidateSet("List","Table","Grid")][String]$Output = "List")

  $DisplayArgs = "("
  $PrimaryArgs = "("
  $Args = ""
  ForEach ($Word in ($SearchString.Split())) {
    $DisplayArgument = "(DisplayName -like `"*$Word*`") -and "
    $DisplayArgs = $DisplayArgs + $DisplayArgument
    $PrimaryArgument = "(EmailAddresses -like `"*$Word*`") -and "
    $PrimaryArgs = $PrimaryArgs + $PrimaryArgument
  }
  $DisplayArgs = $DisplayArgs -replace ".{6}$", ")"
  $PrimaryArgs = $PrimaryArgs -replace ".{6}$", ")"
  $Args = "$DisplayArgs -or $PrimaryArgs"

  Switch ($Output) {
    "List"  {$Outbound = "FL"}
    "Table" {$Outbound = "FT"}
    "Grid"  {$Outbound = "Out-GridView"}
  }

  $Command = "Get-Recipient -Filter {$Args} | Select DisplayName,PrimarySmtpAddress,RecipientTypeDetails,@{Name='EmailAddresses';Expression={(`$_ | Select -ExpandProperty EmailAddresses | Where {`$_ -like `"smtp:*`"}) -ireplace [regex]::Escape(`"smtp:`"),`"`"}} | Sort DisplayName | $Outbound"

  ""
  $Command
  Invoke-Expression $Command
  
}
