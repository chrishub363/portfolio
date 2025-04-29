Function Build-UserMigrationHashTable {
    <#
    .DESCRIPTION
        Builds a hashtable from the master CSV
    .PARAMETER File
        Path to the CSV to be imported
    #>

    Param([Parameter(Mandatory=$true)]$File)

    $UserMigrationFile = Import-Csv -Path $File
    $UserMigrationTable = @{}

    ForEach ($User in $UserMigrationFile) {
        If ($User.'CURRENT WORK EMAIL' -match '\w+') {
            $UserMigrationTable[$User.'CURRENT WORK EMAIL'] = $User.'NEW EMAIL ADDRESS'
        }
    }

    $UserMigrationTable
}

Function Build-DistroMigrationCommands {
    <#
    .DESCRIPTION
        Builds commands to create distribution groups and mail contacts
    .PARAMETER DisplayName
        The display name for the distro
    .PARAMETER PrimarySmtpAddress
        The primary SMTP address for the distro
    .PARAMETER ManagedBy
        The owner/manager of the distro
    .PARAMETER Members
        The members of the distro
    .PARAMETER Hide
        Should the distro be hidden from the GAL?
    .PARAMETER SenderAuth
        Should sender authentication be enabled?
    .PARAMETER Prefix
        The business unit's migration prefix
    .PARAMETER DisplayPrefix
        A different, optional prefix for the Display Name
    .PARAMETER Notes
        Notes to be added to the distribution group
    .PARAMETER MigrationTable
        A hashtable mapping members' legacy email address to their new email address
    #>

    Param([Parameter(Mandatory=$true)]$DisplayName,
          [Parameter(Mandatory=$true)]$PrimarySmtpAddress,
          [Parameter(Mandatory=$false)]$ManagedBy,
          [Parameter(Mandatory=$false)]$Members,
          [Parameter(Mandatory=$true)][ValidateSet("TRUE","FALSE")]$Hide,
          [Parameter(Mandatory=$true)][ValidateSet("TRUE","FALSE")]$SenderAuth,
          [Parameter(Mandatory=$true)]$Prefix,
          [Parameter(Mandatory=$false)]$DisplayPrefix,
          [Parameter(Mandatory=$false)]$Notes,
          [Parameter(Mandatory=$true)]$MigrationTable)

    "#========== $PrimarySmtpAddress =========="

    If ($DisplayPrefix -match '\w+') {
        $NewDisplayName = "NEW - $DisplayPrefix - $DisplayName"
    } Else {
        $NewDisplayName = "NEW - $($Prefix.ToUpper()) - $DisplayName"
    }
    $Alias = "$($Prefix.ToLower()).$($PrimarySmtpAddress.Split('@')[0])"
    $NewPrimarySmtpAddress = "$Alias@example.com"

    $NewOwners = @()
    If ($ManagedBy -match '\w+') {
        $ManagedBy.Split(';') | ForEach-Object {
            If ($MigrationTable.$_) {
                $NewOwners += $MigrationTable.$_
            } Else {
                "# cannot map:  $_"
            }
        }
    }

    $NewMembers = @()
    If ($Members -match '\w+') {
        $Members.Split(';') | ForEach-Object {
            If ($MigrationTable.$_) {
                $NewMembers += $MigrationTable.$_
            } Else {
                "# cannot map:  $_"
            }
        }
    }

    $NewDLCommand = "New-DistributionGroup -Name `"$Alias`" -DisplayName `"$NewDisplayName`" -Alias `"$Alias`" -PrimarySmtpAddress `"$NewprimarySmtpAddress`" -Type `"Distribution`" -MemberJoinRestriction `"Closed`" -MemberDepartRestriction `"Closed`" -RequireSenderAuthenticationEnabled `$$SenderAuth -Notes `"$Notes`" -Confirm:`$false "

    If ($NewOwners -ge 1) {
        $NewDLOwnersCommand = "-ManagedBy "
        ForEach ($Owner in $NewOwners) {$NewDLOwnersCommand = "$NewDLOwnersCommand`"$Owner`","}
        $NewDLOwnersCommand = $NewDLOwnersCommand -replace ".{1}$", " "
        $NewDLCommand = $NewDLCommand + $NewDLOwnersCommand
    }

    If ($NewMembers -ge 1) {
        $NewDLMembersCommand = "-Members "
        ForEach ($Member in $NewMembers) {$NewDLMembersCommand = "$NewDLMembersCommand`"$Member`","}
        $NewDLMembersCommand = $NewDLMembersCommand -replace ".{1}$", " "
        $NewDLCommand = $NewDLCommand + $NewDLMembersCommand
    }

    $SetDLHiddenCommand = "Set-DistributionGroup -Identity `"$NewPrimarySmtpAddress`" -HiddenFromAddressListsEnabled `$$Hide"
    $NewMailContactCommand = "New-MailContact -Name `"$Alias`" -DisplayName `"$NewDisplayName`" -ExternalEmailAddress `"$NewPrimarySmtpAddress`" -OrganizationalUnit `"domain.local/OU/Goes/Here`""

    "   $NewDLCommand"
    "   $SetDLHiddenCommand"
    "      $NewMailContactCommand"


}

$UserMigrationHashTable = Build-UserMigrationHashTable -File "..\Downloads\UserMigrationTable.csv"
$DistroMigrationFile = Import-Csv -Path "..\Downloads\DistroMigrationTable.csv"
$MigrationPrefix = "PREFIX"
$MigrationDisplayPrefix = ""
$Notes = "migration, 20230201, Chris@example.com"


ForEach ($Distro in $DistroMigrationFile) {
    If ($Distro.'Needed?' -like "yes") {
        Build-DistroMigrationCommands -DisplayName $Distro.DisplayName `
                                      -PrimarySmtpAddress $Distro.PrimarySmtpAddress `
                                      -ManagedBy $Distro.ManagedBy `
                                      -Members $Distro.DLMembers `
                                      -Hide $Distro.HiddenFromAddressListsEnabled `
                                      -SenderAuth $Distro.RequireSenderAuthenticationEnabled `
                                      -Prefix $MigrationPrefix `
                                      -DisplayPrefix $MigrationDisplayPrefix `
                                      -Notes $Notes `
                                      -MigrationTable $UserMigrationHashTable
    }
}