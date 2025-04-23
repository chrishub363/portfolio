Function Get-Info {
<#
  .DESCRIPTION
    Attempts to pull essential information about a mail recipient
  .PARAMETER Address
    The address to search for
  .EXAMPLE
    Get-Info "stuff@thing.com"
#>

  Param([Parameter(Mandatory=$true)]$Address)
  
  $Recipient = Get-Recipient $Address
  Switch -Wildcard ($Recipient.RecipientTypeDetails) {
      'PublicFolder'    {$Command = "Get-Recipient `"$Address`" | Select DisplayName,PrimarySmtpAddress,RecipientTypeDetails,@{Name='Identity';Expression={Get-MailPublicFolder `$_ | Select -ExpandProperty EntryID | Get-PublicFolder | Select -ExpandProperty Identity}},@{Name='EmailAddresses';Expression={(`$_ | Select -ExpandProperty EmailAddresses | Where {`$_ -like `"smtp:*`"}) -ireplace [regex]::Escape(`"smtp:`"),`"`"}} | FL" }
      '*distribution*'  {$Command = "Get-DistributionGroup `"$Address`" | Select DisplayName,PrimarySmtpAddress,RecipientTypeDetails,IsDirSynced,RequireSenderAuthenticationEnabled,@{Name='EmailAddresses';Expression={(`$_ | Select -ExpandProperty EmailAddresses | Where {`$_ -like `"smtp:*`"}) -ireplace [regex]::Escape(`"smtp:`"),`"`"}} | FL" }
      default           {$Command = "Get-Recipient `"$Address`" | Select DisplayName,PrimarySmtpAddress,RecipientTypeDetails,@{Name='EmailAddresses';Expression={(`$_ | Select -ExpandProperty EmailAddresses | Where {`$_ -like `"smtp:*`"}) -ireplace [regex]::Escape(`"smtp:`"),`"`"}} | FL" }
  }

  ""
  $Command
  Invoke-Expression $Command
}