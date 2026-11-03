function Convert-DistinguishedNameToDnsDomain {
        <#
.SYNOPSIS
From an LDAP/Active Directory distinguished name, extract domain name and convert to a DNS domain name.

.NOTES
Script: Convert-DistinguishedNameToDnsDomain.ps1
Author: CoPilot, Roman Revell
Tested with PowerShell v.7.6.6

History: 
version 1   2026-09-26

.PARAMETER DistinguishedName
LDAP/Active Directory distinguished name string. To process multiple distinguished names, pipe them in.

.OUTPUTS
System.String.

.EXAMPLE
'CN=mylogonid,OU=personnel,DC=mydomain,DC=net' | Convert-DistinguishedNameToDnsDomain
mydomain.net

#>
    param(
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$DistinguishedName
    )
    process {
        ($DistinguishedName -split ',' |
            Where-Object { $_ -match '^DC=' } |
            ForEach-Object { $_ -replace '^DC=' }) -join '.'
    }
}