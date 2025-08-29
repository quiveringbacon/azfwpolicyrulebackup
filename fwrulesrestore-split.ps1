# Combined Firewall Policy Restore Script
# Uses individual CSV files for network, application, and NAT rules
# Incorporates advanced logic from azfwruledumprestore.ps1

# Prompt for policy creation/restoration
$answer = Read-Host "Do you want a new FW policy created to restore to, y/n?"
if ($answer -eq 'y') {
    $fpname = Read-Host -Prompt "New FW policy name to create and restore to"
    $loc = Read-Host -Prompt "Location for the new policy, default is eastus"
    if ([string]::IsNullOrWhiteSpace($loc)) { $loc = "eastus" }
    $sku = Read-Host -Prompt "New policy sku premium or standard, default is standard"
    if ([string]::IsNullOrWhiteSpace($sku)) { $sku = "Standard" }
    $fprg = Read-Host -Prompt "Resource group the FW policy should be created in"
    Write-Host "Creating $fpname"
    $newazfp = New-AzFirewallPolicy -Name $fpname -ResourceGroupName $fprg -location $loc -SkuTier $sku
    Write-Host "$fpname created"
} else {    
    $fprg = Read-Host -Prompt "Resource group the fw policy is in"
    $fpname = Read-Host -Prompt "FW policy name to restore to"
    $delete = Read-Host -Prompt "!!!WARNING!!! Do you want to allow rules to be deleted and updated, y/n? (If you answer no, the script will not update existing rules and will not delete any rules, only add new rules)"
    if ($delete -eq 'y') {
        Write-Host "Rules will be deleted and updated"
    } else {
        Write-Host "Rules will not be deleted or updated, only new rules will be added"
    }
}

$savepath = Read-Host -Prompt "Path where backup files are, default is c:\temp"
if ([string]::IsNullOrWhiteSpace($savepath)) { $savepath = "c:\temp" }

$targetfp = Get-AzFirewallPolicy -Name $fpname -ResourceGroupName $fprg

# Helper function to process a rule file
function Process-RuleFile {
    param(
        [string]$file,
        [string]$ruleType
    )
    $readObj = Import-Csv $file
    if ($readObj.Count -eq 0) { return }
    $groupName = $readObj[0].RuleCollectionGroupName
    $groupPriority = $readObj[0].RuleCollectionGroupPriority
    try {
        $targetGroup = Get-AzFirewallPolicyRuleCollectionGroup -Name $groupName -ResourceGroupName $fprg -AzureFirewallPolicyName $fpname -ErrorAction Stop
    } catch {
        $targetGroup = New-AzFirewallPolicyRuleCollectionGroup -Name $groupName -Priority $groupPriority -FirewallPolicyObject $targetfp
        $targetGroup = Get-AzFirewallPolicyRuleCollectionGroup -Name $groupName -ResourceGroupName $fprg -AzureFirewallPolicyName $fpname
    }
    $collections = $readObj | Select-Object RuleCollectionName -Unique
    foreach ($collection in $collections) {
        $collectionName = $collection.RuleCollectionName
        $rulesInCollection = $readObj | Where-Object { $_.RuleCollectionName -eq $collectionName }
        $exist = $targetGroup.Properties.RuleCollection | Where-Object { $_.Name -eq $collectionName }
        $priority = $rulesInCollection[0].RulePriority
        $actionType = $rulesInCollection[0].ActionType
        $networkRules = @(); $appRules = @(); $natRules = @()
        foreach ($entry in $rulesInCollection) {
            if ($ruleType -eq "NetworkRule") {
                $RuleParameter = @{
                    Name = $entry.Name
                    Protocol = $entry.Protocols -split ", "
                    DestinationPort = $entry.DestinationPorts -split ", "
                }
                if ($entry.SourceAddresses)      { $RuleParameter['sourceAddress'] = $entry.SourceAddresses -split ", " }
                if ($entry.DestinationAddresses) { $RuleParameter['DestinationAddress'] = $entry.DestinationAddresses -split ", " }
                if ($entry.SourceIPGroups)       { $RuleParameter['SourceIpGroup'] = $entry.SourceIPGroups -split ", " }
                if ($entry.DestinationIPGroups)  { $RuleParameter['DestinationIPGroups'] = $entry.DestinationIPGroups -split ", " }
                $rule = New-AzFirewallPolicyNetworkRule @RuleParameter
                $networkRules += $rule
            } elseif ($ruleType -eq "ApplicationRule") {
                $RuleParameter = @{
                    Name = $entry.Name
                    Protocol = $entry.protocols -split ", "
                    TargetFqdn = $entry.TargetFqdns -split ", "
                }
                if ($entry.SourceAddresses) { $RuleParameter['sourceAddress'] = $entry.SourceAddresses -split ", " }
                if ($entry.SourceIPGroups)  { $RuleParameter['SourceIpGroup'] = $entry.SourceIPGroups -split ", " }
                $rule = New-AzFirewallPolicyApplicationRule @RuleParameter
                $appRules += $rule
            } elseif ($ruleType -eq "NatRule") {
                $RuleParameter = @{
                    Name = $entry.Name
                    Protocol = $entry.Protocols -split ", "
                    DestinationPort = $entry.DestinationPorts -split ", "
                    TranslatedAddress = $entry.TranslatedAddress
                    TranslatedPort = $entry.TranslatedPort
                }
                if ($entry.SourceAddresses)      { $RuleParameter['sourceAddress'] = $entry.SourceAddresses -split ", " }
                if ($entry.DestinationAddresses) { $RuleParameter['DestinationAddress'] = $entry.DestinationAddresses -split ", " }
                if ($entry.SourceIPGroups)       { $RuleParameter['SourceIpGroup'] = $entry.SourceIPGroups -split ", " }
                $rule = New-AzFirewallPolicyNatRule @RuleParameter
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
                $targetGroup.Properties.RuleCollection.Add($NetworkRuleCategoryCollection)
            }
            if ($appRules.Count -gt 0) {
                $ApplicationRuleCollection = @{
                    Name = $collectionName
                    Priority = $priority
                    ActionType = $actionType
                    Rule = $appRules
                }
                $ApplicationRuleCategoryCollection = New-AzFirewallPolicyFilterRuleCollection @ApplicationRuleCollection
                $targetGroup.Properties.RuleCollection.Add($ApplicationRuleCategoryCollection)
            }
            if ($natRules.Count -gt 0) {
                $NatRuleCollection = @{
                    Name = $collectionName
                    Priority = $priority
                    ActionType = $actionType
                    Rule = $natRules
                }
                $NatRuleCategoryCollection = New-AzFirewallPolicyNatRuleCollection @NatRuleCollection
                $targetGroup.Properties.RuleCollection.Add($NatRuleCategoryCollection)
            }
        } else {
            foreach ($entry in $rulesInCollection) {
                if ($ruleType -eq "NetworkRule") {
                    $RuleParameter = @{
                        Name = $entry.Name
                        Protocol = $entry.Protocols -split ", "
                        DestinationPort = $entry.DestinationPorts -split ", "
                    }
                    if ($entry.SourceAddresses)      { $RuleParameter['sourceAddress'] = $entry.SourceAddresses -split ", " }
                    if ($entry.DestinationAddresses) { $RuleParameter['DestinationAddress'] = $entry.DestinationAddresses -split ", " }
                    if ($entry.SourceIPGroups)       { $RuleParameter['SourceIpGroup'] = $entry.SourceIPGroups -split ", " }
                    if ($entry.DestinationIPGroups)  { $RuleParameter['DestinationIPGroups'] = $entry.DestinationIPGroups -split ", " }
                    try {
                        $exist.GetRuleByName($entry.Name)
                        if ($delete -eq 'y') {
                            $exist.RemoveRuleByName($entry.Name)
                            $rule = New-AzFirewallPolicyNetworkRule @RuleParameter
                            $exist.Rules.Add($rule)
                        } else {
                            Write-Host "Rule $($entry.Name) already exists, not updating or deleting it"
                        }
                    } catch {
                        $rule = New-AzFirewallPolicyNetworkRule @RuleParameter
                        $exist.Rules.Add($rule)
                    }
                } elseif ($ruleType -eq "ApplicationRule") {
                    $RuleParameter = @{
                        Name = $entry.Name
                        Protocol = $entry.protocols -split ", "
                        TargetFqdn = $entry.TargetFqdns -split ", "
                    }
                    if ($entry.SourceAddresses) { $RuleParameter['sourceAddress'] = $entry.SourceAddresses -split ", " }
                    if ($entry.SourceIPGroups)  { $RuleParameter['SourceIpGroup'] = $entry.SourceIPGroups -split ", " }
                    try {
                        $exist.GetRuleByName($entry.Name)
                        if ($delete -eq 'y') {
                            $exist.RemoveRuleByName($entry.Name)
                            $rule = New-AzFirewallPolicyApplicationRule @RuleParameter
                            $exist.Rules.Add($rule)
                        } else {
                            Write-Host "Rule $($entry.Name) already exists, not updating or deleting it"
                        }
                    } catch {
                        $rule = New-AzFirewallPolicyApplicationRule @RuleParameter
                        $exist.Rules.Add($rule)
                    }
                } elseif ($ruleType -eq "NatRule") {
                    $RuleParameter = @{
                        Name = $entry.Name
                        Protocol = $entry.Protocols -split ", "
                        DestinationPort = $entry.DestinationPorts -split ", "
                        TranslatedAddress = $entry.TranslatedAddress
                        TranslatedPort = $entry.TranslatedPort
                    }
                    if ($entry.SourceAddresses)      { $RuleParameter['sourceAddress'] = $entry.SourceAddresses -split ", " }
                    if ($entry.DestinationAddresses) { $RuleParameter['DestinationAddress'] = $entry.DestinationAddresses -split ", " }
                    if ($entry.SourceIPGroups)       { $RuleParameter['SourceIpGroup'] = $entry.SourceIPGroups -split ", " }
                    try {
                        $exist.GetRuleByName($entry.Name)
                        if ($delete -eq 'y') {
                            $exist.RemoveRuleByName($entry.Name)
                            $rule = New-AzFirewallPolicyNatRule @RuleParameter
                            $exist.Rules.Add($rule)
                        } else {
                            Write-Host "Rule $($entry.Name) already exists, not updating or deleting it"
                        }
                    } catch {
                        $rule = New-AzFirewallPolicyNatRule @RuleParameter
                        $exist.Rules.Add($rule)
                    }
                }
            }
        }
    }
    Set-AzFirewallPolicyRuleCollectionGroup -Name $groupName -Priority $groupPriority -RuleCollection $targetGroup.Properties.RuleCollection -FirewallPolicyObject $targetfp
}

# Process all rule files
foreach ($file in Get-ChildItem "$savepath\*-netrules.csv" -File) {
    Process-RuleFile -file $file.FullName -ruleType "NetworkRule"
}
foreach ($file in Get-ChildItem "$savepath\*-apprules.csv" -File) {
    Process-RuleFile -file $file.FullName -ruleType "ApplicationRule"
}
foreach ($file in Get-ChildItem "$savepath\*-dnatrules.csv" -File) {
    Process-RuleFile -file $file.FullName -ruleType "NatRule"
}

Write-Host "Firewall policy restore completed."
