function Get-ADMembership {
    <#
.SYNOPSIS
Get the distinguished names of all groups that the specified object is a member of.
     
.DESCRIPTION 
Get the distinguished names of all groups that the specified object is a member of. The -recursive option can be set to get the groups each group is a member of and so forth.
Pipe this command's output to Get-ADGroup to get the other properties of each group.

.NOTES
Script: Get-ADMembership.ps1
Author: Roman Revell
Tested with PowerShell v.7.4.6
Requirements:
    Module: Active Directory

History: 
version 2.0.2   2025-01-20 Converted to module function.
version 2.0.1   2025-01-20
version 2       2025-01-20

.PARAMETER Identity
Enter the identity property of the user or group you want the group membership for. This uses Get-ADObject; thus you can identify the object by its distinguished name or GUID.

.PARAMETER Recursive
Switch to get the groups each group is a member of and so forth. This gives you all effective group memberships of the object you specified.

.OUTPUTS
System.String. One or more distinguished names.

.EXAMPLE
Get-ADGroup "Backup Operators" | Get-ADMembership -Recursive | Get-AdGroup | select Name

#>
    param (
        [parameter(Mandatory, ValueFromPipeline)][string]
        $Identity,
        [switch]
        $Recursive
    )
    Set-StrictMode -Version 3.0
    function Get-MemberOfRecursive {
        # Return a collection of group objects for each group that the queried user or group is a member of.
        Param(
            [string]$DistinguishedName,
            [array]$detectedGroups = @() # Groups already found in the memberof property. Pass to function in order to exclude in order to avoid looping nested groups.
        
        )
        # returns list of distinguished names of groups that this object is a member of (excluding already detected groups)
        [array]$memberOf = (Get-ADObject $DistinguishedName -Properties memberOf | Select-Object -ExpandProperty memberof | Where-Object { $_ -notin $detectedGroups })
        $containingGroups = $memberOf
        foreach ( $group in $memberOf) {
            if ($group -notin $detectedGroups) {
                [array]$foundGroups = Get-MemberOfRecursive -DistinguishedName $group -detectedGroups ($containingGroups + $detectedGroups | Sort-Object -Unique)
                $containingGroups += $foundGroups
                $detectedGroups += $foundGroups    
            }
        }

        return $containingGroups
    }

    $ADObject = Get-ADObject $Identity
    if (!$ADObject) {
        Write-Warning "AD object $Identity not found. Identity must be a distinguished name or GUID. If you don't have that, you can use Get-ADUser or Get-ADGroup to retreive it."
        return
    }

    switch ($ADObject.ObjectClass) {
        group { 
            if (!$Recursive) {
                # memberof is a list of distinguished names
                Get-ADGroup -Identity $ADObject.DistinguishedName -Properties memberof | Select-Object -ExpandProperty memberof
            }
            else {
                Get-MemberOfRecursive $ADObject.DistinguishedName
            }
        }
        user {  
            if (!$Recursive) {
                $user = Get-ADUser -Identity $ADObject.DistinguishedName -Properties primaryGroupID, objectSid, memberOf
                $user.memberOf
                <# The primary group is not included in the memberof property, nor is its distinguished name readily available
                So, we need to get that.#>
                # Calculate the primary group's SID
                $primaryGroupSid = $User.objectSid.AccountDomainSid.Value + "-" + $user.primaryGroupID
                # Find the group with the calculated SID
                $primaryGroup = Get-ADGroup -Filter "objectSid -eq '$primaryGroupSid'"
                # Output the distinguished name of the primary group
                $primaryGroup.DistinguishedName
            }
            else {
                $user = Get-ADUser -Identity $ADObject.DistinguishedName -Properties distinguishedName, primaryGroupID, objectSid
                [array]$detectedGroups = Get-MemberOfRecursive $user.DistinguishedName
                # Output the names of the groups found from the memberOf property recursive search
                $detectedGroups
                <# The primary group is not included in the memberof property, nor is its distinguished name readily available
                So, we need to get that.#>
                # Calculate the primary group's SID
                $primaryGroupSid = $User.objectSid.AccountDomainSid.Value + "-" + $user.primaryGroupID
                # Find the group with the calculated SID
                $primaryGroup = Get-ADGroup -Filter "objectSid -eq '$primaryGroupSid'"
                # Output the distinguished name of the primary group
                $primaryGroup.DistinguishedName
                $detectedGroups += $primaryGroup.DistinguishedName
                # Get the membership of the user's primary group using a recursive search, but exclude any groups already found
                Get-MemberOfRecursive -DistinguishedName $primaryGroup.DistinguishedName -detectedGroups $detectedGroups
            }
        }
        default {
            Write-Error "The input identity $Identity must be either a user or group. It is a $($ADObject.ObjectClass)."
        }
    }
}