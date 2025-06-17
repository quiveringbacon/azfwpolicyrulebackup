#Provide Input. Firewall Policy Name, Firewall Policy Resource Group & Firewall Policy Rule Collection Group Name

$answer = Read-Host "Do you want a new FW policy created to restore to, y/n?"
if ($answer -eq 'y') { 
    $fpname = Read-Host -Prompt "New FW policy name to create and restore to"
    $loc = Read-Host -Prompt "Location for the new policy, default is eastus"
    if ([string]::IsNullOrWhiteSpace($loc)) {
        $loc = "eastus"
    }
    $sku = Read-Host -Prompt "New policy sku premium or standard, default is standard"
    if ([string]::IsNullOrWhiteSpace($sku)) {
        $sku = "Standard"
    }
    $fprg = Read-Host -Prompt "Resource group the FW policy should be created in" 
    Write-Host "Creating $fpname"
    $newazfp = New-AzFirewallPolicy -Name $fpname -ResourceGroupName $fprg -location $loc -SkuTier $sku
    Write-Host "$fpname created"
} else {
    $fpname = Read-Host -Prompt "FW policy name to restore to"
    $fprg = Read-Host -Prompt "Resource group the fw policy is in"
    $delete = Read-Host -Prompt "!!!WARNING!!! Do you want to allow rules to be deleted and updated, y/n? (If you answer no, the script will not update existing rules and will not delete any rules, only add new rules)"
    if ($delete -eq 'y') {
        Write-Host "Rules will be deleted and updated"
    } else {
        Write-Host "Rules will not be deleted or updated, only new rules will be added"
    }
}

$savepath = Read-Host -Prompt "Path where backup files are, default is c:\temp"
if ([string]::IsNullOrWhiteSpace($savepath)) {
    $savepath = "c:\temp"
}

$targetfp = Get-AzFirewallPolicy -Name $fpname -ResourceGroupName $fprg

$file = (Get-ChildItem "${savepath}\allrules.csv" -File)
$readObj1 = Import-Csv $file

# Get unique Rule Collection Groups
$uniqueGroups = $readObj1 | Select-Object RuleCollectionGroupName, RuleCollectionGroupPriority -Unique

foreach ($group in $uniqueGroups) {
    $rcgName = $group.RuleCollectionGroupName
    $rcgPriority = $group.RuleCollectionGroupPriority

    try {
        $target1 = Get-AzFirewallPolicyRuleCollectionGroup -Name $rcgName -ResourceGroupName $fprg -AzureFirewallPolicyName $fpname -ErrorAction Stop
    } catch {
        $targetrcg1 = New-AzFirewallPolicyRuleCollectionGroup -Name $rcgName -Priority $rcgPriority -FirewallPolicyObject $targetfp    
        $target1 = Get-AzFirewallPolicyRuleCollectionGroup -Name $rcgName -ResourceGroupName $fprg -AzureFirewallPolicyName $fpname
    }

    # Get unique Rule Collections for this group
    $collections = $readObj1 | Where-Object { $_.RuleCollectionGroupName -eq $rcgName } | Select-Object RuleCollectionName -Unique

    foreach ($collection in $collections) {
        $collectionName = $collection.RuleCollectionName
        $rulesInCollection = $readObj1 | Where-Object { $_.RuleCollectionGroupName -eq $rcgName -and $_.RuleCollectionName -eq $collectionName }

        $exist = $target1.Properties.RuleCollection | Where-Object { $_.Name -eq $collectionName }

        # Prepare rule arrays
        $networkRules = @()
        $appRules = @()
        $natRules = @()
        $priority = $null
        $actionType = $null

        foreach ($entry in $rulesInCollection) {
            $priority = $entry.Priority
            $actionType = $entry.ActionType

            if ($entry.RuleType -eq "NetworkRule") {
                $RuleParameter1 = @{
                    Name = $entry.Name
                    Protocol = $entry.Protocols -split ", "
                    DestinationPort = $entry.DestinationPorts -split ", "
                }
                if ($entry.SourceAddresses)      { $RuleParameter1['sourceAddress'] = $entry.SourceAddresses -split ", " }
                if ($entry.DestinationAddresses) { $RuleParameter1['DestinationAddress'] = $entry.DestinationAddresses -split ", " }
                if ($entry.SourceIpGroups)       { $RuleParameter1['SourceIpGroup'] = $entry.SourceIpGroups -split ", " }
                if ($entry.DestinationIpGroups)  { $RuleParameter1['DestinationIPGroups'] = $entry.DestinationIpGroups -split ", " }
                $rule = New-AzFirewallPolicyNetworkRule @RuleParameter1
                $networkRules += $rule
            }
            elseif ($entry.RuleType -eq "ApplicationRule") {
                $RuleParameter2 = @{
                    Name = $entry.Name
                    Protocol = $entry.AppruleProtocols -split ", "
                    TargetFqdn = $entry.TargetFqdns -split ", "
                }
                if ($entry.SourceAddresses) { $RuleParameter2['sourceAddress'] = $entry.SourceAddresses -split ", " }
                if ($entry.SourceIpGroups)  { $RuleParameter2['SourceIpGroup'] = $entry.SourceIpGroups -split ", " }                
                $rule = New-AzFirewallPolicyApplicationRule @RuleParameter2
                $appRules += $rule
            }
            elseif ($entry.RuleType -eq "NatRule") {
                $RuleParameter3 = @{
                    Name = $entry.Name
                    Protocol = $entry.Protocols -split ", "
                    DestinationPort = $entry.DestinationPorts -split ", "
                    TranslatedAddress = $entry.TranslatedAddress
                    TranslatedPort = $entry.TranslatedPort
                }
                if ($entry.SourceAddresses)      { $RuleParameter3['sourceAddress'] = $entry.SourceAddresses -split ", " }
                if ($entry.DestinationAddresses) { $RuleParameter3['DestinationAddress'] = $entry.DestinationAddresses -split ", " }
                if ($entry.SourceIpGroups)       { $RuleParameter3['SourceIpGroup'] = $entry.SourceIpGroups -split ", " }
                $rule = New-AzFirewallPolicyNatRule @RuleParameter3
                $natRules += $rule
            }
        }

        if ($null -eq $exist) {
            if ($networkRules.Count -gt 0) {
                $NetworkRuleCollection = @{
                    Name = $collectionName
                    Priority = $priority
                    ActionType = $actionType
                    Rule = $networkRules
                }
                $NetworkRuleCategoryCollection = New-AzFirewallPolicyFilterRuleCollection @NetworkRuleCollection
                $target1.Properties.RuleCollection.Add($NetworkRuleCategoryCollection)
            }
            if ($appRules.Count -gt 0) {
                $ApplicationRuleCollection = @{
                    Name = $collectionName
                    Priority = $priority
                    ActionType = $actionType
                    Rule = $appRules
                }
                $ApplicationRuleCategoryCollection = New-AzFirewallPolicyFilterRuleCollection @ApplicationRuleCollection
                $target1.Properties.RuleCollection.Add($ApplicationRuleCategoryCollection)
            }
            if ($natRules.Count -gt 0) {
                $NatRuleCollection = @{
                    Name = $collectionName
                    Priority = $priority
                    ActionType = $actionType
                    Rule = $natRules
                }
                $NatRuleCategoryCollection = New-AzFirewallPolicyNatRuleCollection @NatRuleCollection
                $target1.Properties.RuleCollection.Add($NatRuleCategoryCollection)
            }
        } else {
            # If the collection exists, update or delete rules based on the delete flag
            foreach ($entry in $rulesInCollection) {
                if ($entry.RuleType -eq "NetworkRule") {
                    $RuleParameter1 = @{
                        Name = $entry.Name
                        Protocol = $entry.Protocols -split ", "
                        DestinationPort = $entry.DestinationPorts -split ", "
                    }
                    if ($entry.SourceAddresses)      { $RuleParameter1['sourceAddress'] = $entry.SourceAddresses -split ", " }
                    if ($entry.DestinationAddresses) { $RuleParameter1['DestinationAddress'] = $entry.DestinationAddresses -split ", " }
                    if ($entry.SourceIpGroups)       { $RuleParameter1['SourceIpGroup'] = $entry.SourceIpGroups -split ", " }
                    if ($entry.DestinationIpGroups)  { $RuleParameter1['DestinationIPGroups'] = $entry.DestinationIpGroups -split ", " }
                    try {
                        $exist.GetRuleByName($entry.Name)
                        if ($delete -eq 'y') {
                            $exist.RemoveRuleByName($entry.Name)
                            $rule = New-AzFirewallPolicyNetworkRule @RuleParameter1
                            $exist.Rules.Add($rule)
                        } else {
                            Write-Host "Rule $($entry.Name) already exists, not updating or deleting it"
                        }
                    } catch {
                        $rule = New-AzFirewallPolicyNetworkRule @RuleParameter1
                        $exist.Rules.Add($rule)
                    }
                }
                elseif ($entry.RuleType -eq "ApplicationRule") {
                    $RuleParameter2 = @{
                        Name = $entry.Name
                        Protocol = $entry.AppruleProtocols -split ", "
                        TargetFqdn = $entry.TargetFqdns -split ", "
                    }
                    if ($entry.SourceAddresses) { $RuleParameter2['sourceAddress'] = $entry.SourceAddresses -split ", " }
                    if ($entry.SourceIpGroups)  { $RuleParameter2['SourceIpGroup'] = $entry.SourceIpGroups -split ", " }
                    try {
                        $exist.GetRuleByName($entry.Name)
                        if ($delete -eq 'y') {
                            $exist.RemoveRuleByName($entry.Name)
                            $rule = New-AzFirewallPolicyApplicationRule @RuleParameter2
                            $exist.Rules.Add($rule)
                        } else {
                            Write-Host "Rule $($entry.Name) already exists, not updating or deleting it"
                        }
                    } catch {
                        $rule = New-AzFirewallPolicyApplicationRule @RuleParameter2
                        $exist.Rules.Add($rule)
                    }
                }
                elseif ($entry.RuleType -eq "NatRule") {
                    $RuleParameter3 = @{
                        Name = $entry.Name
                        Protocol = $entry.Protocols -split ", "
                        DestinationPort = $entry.DestinationPorts -split ", "
                        TranslatedAddress = $entry.TranslatedAddress
                        TranslatedPort = $entry.TranslatedPort
                    }
                    if ($entry.SourceAddresses)      { $RuleParameter3['sourceAddress'] = $entry.SourceAddresses -split ", " }
                    if ($entry.DestinationAddresses) { $RuleParameter3['DestinationAddress'] = $entry.DestinationAddresses -split ", " }
                    if ($entry.SourceIpGroups)       { $RuleParameter3['SourceIpGroup'] = $entry.SourceIpGroups -split ", " }
                    try {
                        $exist.GetRuleByName($entry.Name)
                        if ($delete -eq 'y') {
                            $exist.RemoveRuleByName($entry.Name)
                            $rule = New-AzFirewallPolicyNatRule @RuleParameter3
                            $exist.Rules.Add($rule)
                        } else {
                            Write-Host "Rule $($entry.Name) already exists, not updating or deleting it"
                        }
                    } catch {
                        $rule = New-AzFirewallPolicyNatRule @RuleParameter3
                        $exist.Rules.Add($rule)
                    }
                }
            }
        }
    }
    Set-AzFirewallPolicyRuleCollectionGroup -Name $rcgName -Priority $rcgPriority -RuleCollection $target1.Properties.RuleCollection -FirewallPolicyObject $targetfp
}