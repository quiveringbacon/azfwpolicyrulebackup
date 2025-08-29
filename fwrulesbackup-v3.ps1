
$rg = Read-Host -Prompt "Resource group the fw policy is in"

$policyname = Read-Host -Prompt "FW policy name to backup"

$savepath = Read-Host -Prompt "Path to save files to, default is c:\temp"
if ([string]::IsNullOrWhiteSpace($savepath))
{
$savepath = "c:\temp"
}

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
    
}
