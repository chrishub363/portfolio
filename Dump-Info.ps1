<#
    Simple script to collect details about recipients in Exchange.
    This script will pull out the DisplayName, and PrimarySmtpAddress, identify what kind of recipient it is, and determine ownership/membership if applicable.
    Note that this script assumes permissions on SMBs are assigned by distribution groups - reporting may be off if that's not the case.
#>

#$Recipients = Get-Recipient -filter {DisplayName -like "*billing*"} | Sort DisplayName | Select DisplayName,PrimarySmtpAddress,RecipientType,RecipientTypeDetails

$List = Get-Content -Path "..\..\downloads\list.txt"
$Recipients = $List | %{Get-Recipient $_} | Sort DisplayName | Select DisplayName,PrimarySmtpAddress,RecipientType,RecipientTypeDetails

$Collection = @()
$Counter = 0
ForEach ($Item in $Recipients) {
    $Counter++
    Write-Progress -Activity "Dumping information..." -Status "$($Item.PrimarySmtpAddress)" -PercentComplete (($Counter / $Recipients.Count) * 100)
    Switch -Wildcard ($Item.RecipientTypeDetails) {
        "MailUniversal*" {
            # Write-Host "Distribution Group - $($Item.PrimarySmtpAddress)"
            $Collection += Get-DistributionGroup -Identity $Item.PrimarySmtpAddress | Select DisplayName,PrimarySmtpAddress,@{Name="Type"; Expression={"Distribution Group"}},@{Name="Owners"; Expression={"$($_.ManagedBy | %{Get-Recipient $_ | Select -ExpandProperty PrimarySmtpAddress})".replace(' ','; ')}},@{Name="Members"; Expression={"$(Get-DistributionGroupMember $_.PrimarySmtpAddress -ResultSize Unlimited | Sort PrimarySmtpAddress | Select -ExpandProperty PrimarySmtpAddress)".replace(' ','; ')}}
        }
        "GroupMailbox" {
            # Write-Host "M365 Group - $($Item.PrimarySmtpAddress)"
            $Collection += Get-UnifiedGroup -Identity $Item.PrimarySmtpAddress | Select DisplayName,PrimarySmtpAddress,@{Name="Type"; Expression={"M365 Group"}},@{Name="Owners"; Expression={"$(Get-UnifiedGroupLinks $Item.PrimarySmtpAddress -LinkType Owners | Sort PrimarySmtpAddress | Select -ExpandProperty PrimarySmtpAddress)".replace(' ','; ')}},@{Name="Members"; Expression={"$(Get-UnifiedGroupLinks $Item.PrimarySmtpAddress -LinkType Members | Sort PrimarySmtpAddress | Select -ExpandProperty PrimarySmtpAddress)".replace(' ','; ')}}
        }
        "SharedMailbox" {
            # Write-Host "Shared Mailbox - $($Item.PrimarySmtpAddress)"
            $Collection += Get-Mailbox -Identity $Item.PrimarySmtpAddress | Select DisplayName,PrimarySmtpAddress,@{Name="Type"; Expression={"Shared Mailbox"}},@{Name="Owners"; Expression={""}},@{Name="Members"; Expression={"$(Get-MailboxPermission $Item.PrimarySmtpAddress | Where {$_.AccessRights -eq "FullAccess"} | %{Get-DistributionGroupMember $_.User -ResultSize Unlimited | Sort PrimarySmtpAddress | Select -ExpandProperty PrimarySmtpAddress})".replace(' ','; ')}}
        }
        "UserMailbox" {
            # Write-Host "User Mailbox - $($Item.PrimarySmtpAddress)"
            $Collection += Get-Mailbox -Identity $Item.PrimarySmtpAddress | Select DisplayName,PrimarySmtpAddress,@{Name="Type"; Expression={"User Mailbox"}},@{Name="Owners"; Expression={""}},@{Name="Members"; Expression={""}}
        }
        Default {
            Write-host "Cannot identify $($Item.PrimarySmtpAddress), $($Item.RecipientType), $($Item.RecipientTypeDetails)"
            $Collection += Get-Recipient -Identity $Item.PrimarySmtpAddress | Select DisplayName,PrimarySmtpAddress,@{Name="Type"; Expression={$_.RecipientTypeDetails}},@{Name="Owners"; Expression={""}},@{Name="Members"; Expression={""}}
        }
    }
}

$DateStamp = Get-Date -Format "yyyyMMdd"
$Collection | Export-CSV -NoTypeInformation -Path ".\info.$DateStamp.csv"