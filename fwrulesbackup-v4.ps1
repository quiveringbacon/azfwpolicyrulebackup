$rg = Read-Host -Prompt "Resource group the fw policy is in"

$policyname = Read-Host -Prompt "FW policy name to backup"

$savepath = Read-Host -Prompt "Path to save files to, default is c:\temp"
if ([string]::IsNullOrWhiteSpace($savepath))
{
$savepath = "c:\temp"
}
# Ensure the export directory exists
if (-not (Test-Path -Path $savepath)) {
    New-Item -Path $savepath -ItemType Directory -Force
}

# Hash table to track IP groups that have been exported
$exportedIPGroups = @{}

$colgroups = Get-AzFirewallPolicy -Name $policyname -ResourceGroupName $rg
foreach ($colgroup in $colgroups.RuleCollectionGroups)
{
    $c = Out-String -InputObject $colgroup -Width 500
    $collist= $c -split "/"
    $colname = ($collist[-1]).Trim()
    
    $rulecolgroup = Get-AzFirewallPolicyRuleCollectionGroup -Name $colname -ResourceGroupName $rg -AzureFirewallPolicyName $policyname
    
    $returnObj1 = @()
    $returnObj2 = @()
    $returnObj3 = @()
    foreach ($rulecol in $rulecolgroup.Properties.RuleCollection) {
        
        if ($rulecol.rules.RuleType -contains "NetworkRule")
        {
            
            
            foreach ($rule in $rulecol.rules)
            {
                $properties = [ordered]@{
                RuleCollectionGroupName = $rulecolgroup.Name;
                RuleCollectionGroupPriority = $rulecolgroup.Properties.Priority;
                RuleCollectionName = $rulecol.Name;
                RulePriority = $rulecol.Priority;
                ActionType = $rulecol.Action.Type;
                RuleCollectionType = $rulecol.RuleCollectionType;
                Name = $rule.Name;
                protocols = $rule.protocols -join ", ";
                SourceAddresses = $rule.SourceAddresses -join ", ";
                DestinationAddresses = $rule.DestinationAddresses -join ", ";
                SourceIPGroups = $rule.SourceIPGroups -join ", ";
                DestinationIPGroups = $rule.DestinationIPGroups -join ", ";
                DestinationPorts = $rule.DestinationPorts -join ", ";
                DestinationFQDNs = $rule.DestinationFQDNs -join ", ";
                }
            $obj = New-Object psobject -Property $properties
            $returnObj1 += $obj
            
            }
    
                #change c:\temp to the path to export the CSV
            $returnObj1 | Export-Csv ${savepath}\${colname}-netrules.csv -NoTypeInformation
            
    
        }
        
        if ($rulecol.rules.RuleType -contains "ApplicationRule")
        {
            
            foreach ($rule in $rulecol.rules)
            {
                $properties = [ordered]@{
                RuleCollectionGroupName = $rulecolgroup.Name;
                RuleCollectionGroupPriority = $rulecolgroup.Properties.Priority;
                RuleCollectionName = $rulecol.Name;
                RulePriority = $rulecol.Priority;
                ActionType = $rulecol.Action.Type;
                RuleCollectionType = $rulecol.RuleCollectionType;
                Name = $rule.Name;
                protocols = $rule.protocols.protocolType -join ", ";
                SourceAddresses = $rule.SourceAddresses -join ", ";
                TargetFqdns = $rule.TargetFqdns -join ", ";
                SourceIPGroups = $rule.SourceIPGroups -join ", ";
                WebCategories = $rule.WebCategories -join ", ";
                TargetUrls = $rule.TargetUrls -join ", ";
                
                }
                
            $obj = New-Object psobject -Property $properties
            $returnObj2 += $obj
            
            }
            
            #change c:\temp to the path to export the CSV
            $returnObj2 | Export-Csv ${savepath}\${colname}-apprules.csv -NoTypeInformation
            
        }
        
        if ($rulecol.rules.RuleType -contains "NatRule")
        {
            
            foreach ($rule in $rulecol.rules)
            {
                $properties = [ordered]@{
                RuleCollectionGroupName = $rulecolgroup.Name;
                RuleCollectionGroupPriority = $rulecolgroup.Properties.Priority;
                RuleCollectionName = $rulecol.Name;
                RulePriority = $rulecol.Priority;
                ActionType = $rulecol.Action.Type;
                RuleCollectionType = $rulecol.RuleCollectionType;
                Name = $rule.Name;
                protocols = $rule.Protocols -join ", ";
                SourceAddresses = $rule.SourceAddresses -join ", ";
                TranslatedAddress = $rule.TranslatedAddress -join ", ";
                SourceIPGroups = $rule.SourceIPGroups -join ", ";
                TranslatedPort = $rule.TranslatedPort -join ", ";
                DestinationAddresses = $rule.DestinationAddresses -join ", ";
                DestinationPorts = $rule.DestinationPorts -join ", ";
                }
                
            $obj = New-Object psobject -Property $properties
            $returnObj3 += $obj
            
            }
            
            #change c:\temp to the path to export the CSV
            $returnObj3 | Export-Csv ${savepath}\${colname}-dnatrules.csv -NoTypeInformation
            
        }
        
    }
    
    
            # Export IP Groups used in this rule collection group
foreach ($rulecol in $rulecolgroup.Properties.RuleCollection) {
    foreach ($rule in $rulecol.rules) {
        # Collect all IP group IDs from the rule
        $allIPGroups = @()
        if ($rule.SourceIPGroups) {
            $allIPGroups += $rule.SourceIPGroups
        }
        if ($rule.DestinationIPGroups) {
            $allIPGroups += $rule.DestinationIPGroups
        }
        
        # Process each unique IP group
        foreach ($ipGroupId in $allIPGroups) {
            if ($ipGroupId -and -not $exportedIPGroups.ContainsKey($ipGroupId)) {
                try {
                    # Parse the IP group ID to extract name and resource group
                    # Format: /subscriptions/{subscription}/resourceGroups/{rg}/providers/Microsoft.Network/ipGroups/{name}
                    $parts = $ipGroupId -split "/"
                    
                    # Find the resource group name (comes after 'resourceGroups')
                    $rgIndex = [array]::IndexOf($parts, "resourceGroups")
                    $ipGroupResourceGroup = $parts[$rgIndex + 1]
                    
                    # Get the IP group name (last element in the path)
                    $ipGroupName = $parts[-1]
                    
                    # Get the IP group details
                    $ipGroup = Get-AzIpGroup -Name $ipGroupName -ResourceGroupName $ipGroupResourceGroup
                    
                    if ($ipGroup) {
                        $ipGroupData = @()
                        foreach ($ip in $ipGroup.IpAddresses) {
                            $ipGroupData += [pscustomobject]@{
                                IPGroupName = $ipGroupName;
                                IPGroupId = $ipGroupId;
                                IPAddress = $ip;
                                ResourceGroup = $ipGroupResourceGroup;
                            }
                        }
                        
                        # Export to CSV
                        $ipGroupData | Export-Csv "${savepath}\${ipGroupName}-ipgroup.csv" -NoTypeInformation
                        
                        # Mark as exported
                        $exportedIPGroups[$ipGroupId] = $true
                        
                        Write-Host "Exported IP Group: $ipGroupName"
                    }
                }
                catch {
                    Write-Warning "Failed to export IP Group: $ipGroupId - $_"
                }
            }
        }
    }
}
        }
    
    
