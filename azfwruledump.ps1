$rg = Read-Host -Prompt "Resource group the fw policy is in"

$policyname = Read-Host -Prompt "FW policy name to backup"

# Define the export directory
$exportDirectory = Read-Host -Prompt "Path to save files to, default is c:\temp\fw1"
if ([string]::IsNullOrWhiteSpace($exportDirectory))
{
$exportDirectory = "c:\temp\fw1"
}
 
# Ensure the export directory exists
if (-not (Test-Path -Path $exportDirectory)) {
    New-Item -Path $exportDirectory -ItemType Directory -Force
}
    # Retrieve firewall policy
    
    $colgroups = Get-AzFirewallPolicy -Name $policyname -ResourceGroupName $rg
 
    foreach ($colgroup in $colgroups.RuleCollectionGroups) {
        $c = Out-String -InputObject $colgroup -Width 500
        $collist = $c -split "/"
        $colname = ($collist[-1]).Trim()
 
        $rulecolgroup = Get-AzFirewallPolicyRuleCollectionGroup -Name $colname -ResourceGroupName $rg -AzureFirewallPolicyName $policyname

        $biglist = @()
        foreach ($rulecol in $rulecolgroup.Properties.RuleCollection){
 
            foreach ($rule in $rulecol.Rules) {
                
                $Rules = [PSCustomObject]@{
                    RuleCollectionGroupName = $rulecolgroup.Name;
                    RuleCollectionGroupPriority = $rulecolgroup.Properties.Priority;
                    RuleCollectionName = $rulecol.Name;
                    Name                = $rule.Name
                    RuleType            = $rule.ruletype
                    Priority            = $rulecol.Priority
                    ActionType          = $rulecol.Action.Type;
                    TranslatedPort      = $rule.TranslatedPort
                    TranslatedAddress   = $rule.TranslatedAddress
                    TerminateTLS        = $rule.TerminateTLS
                    SourceAddresses     = ($rule.SourceAddresses -join ",")
                    TargetFqdns         = ($rule.TargetFqdns -join ",")
                    Protocols           = ($rule.Protocols -join ",")
                    AppruleProtocols    = ($rule.Protocols.protocolType -join ",")
                    DestinationAddresses = ($rule.DestinationAddresses -join ",")
                    SourceIpGroups      = ($rule.SourceIpGroups -join ",")
                    WebCategories       = ($rule.WebCategories -join ",")
                    TargetUrls          = ($rule.TargetUrls -join ",")
                    DestinationIpGroups = ($rule.DestinationIpGroups -join ",")
                    DestinationPorts    = ($rule.DestinationPorts -join ",")
                    DestinationFqdns    = ($rule.DestinationFqdns -join ",")
                    
                }            
                $biglist += $Rules            
                
            }
        }
        $biglist | Export-Csv -Path "$exportDirectory\allrules.csv" -Append -NoTypeInformation -Force
    }
