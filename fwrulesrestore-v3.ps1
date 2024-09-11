#Provide Input. Firewall Policy Name, Firewall Policy Resource Group & Firewall Policy Rule Collection Group Name


$answer = read-host "Do you want a new FW policy created to restore to, y/n?"
if ($answer -eq 'y') { 
  $fpname = Read-Host -Prompt "New FW policy name to create and restore to"
  $loc = Read-Host -Prompt "Location for the new policy, default is eastus"
  if ([string]::IsNullOrWhiteSpace($loc))
  {
  $loc = "eastus"
  }
  $sku = Read-Host -Prompt "New policy sku premium or standard, default is standard"
  if ([string]::IsNullOrWhiteSpace($sku))
  {
  $sku = "Standard"
  }
  
  $fprg = Read-Host -Prompt "Resource group the FW policy should be created in" 
  Write-Host "Creating "$fpname
  $newazfp = New-AzFirewallPolicy -Name $fpname -ResourceGroupName $fprg -location $loc -SkuTier $sku
  Write-Host $fpname" created"
} else {
  $fpname = Read-Host -Prompt "FW policy name to restore to"
  $fprg = Read-Host -Prompt "Resource group the fw policy is in"
} 


$savepath = Read-Host -Prompt "Path where backup files are, default is c:\temp"
if ([string]::IsNullOrWhiteSpace($savepath))
{
$savepath = "c:\temp"
}


$targetfp = Get-AzFirewallPolicy -Name $fpname -ResourceGroupName $fprg

# Change the folder where the CSV is located
foreach($file in (Get-ChildItem ${savepath}\"*"-netrules.csv -File))


{

    
    
    $readObj1 = import-csv $file
    
    $colname1 = $readObj1[0].psobject.properties.value[0]
    try {
        $target1 = Get-AzFirewallPolicyRuleCollectionGroup -Name $colname1 -ResourceGroupName $fprg -AzureFirewallPolicyName $fpname -ErrorAction Stop
    }
    catch {
        
        $targetrcg1 = New-AzFirewallPolicyRuleCollectionGroup -Name $colname1 -Priority 200 -FirewallPolicyObject $targetfp    
        $target1 = Get-AzFirewallPolicyRuleCollectionGroup -Name $colname1 -ResourceGroupName $fprg -AzureFirewallPolicyName $fpname
    }
    
    $testcsv = $readObj1 | Select-Object -ExpandProperty RuleCollectionName -Unique
    
    
    ForEach ($item1 in $testcsv)
    {
        
        $2 = ($readObj1 | Where-Object {$_.RuleCollectionName -eq $item1})
        
        $RulesfromCSV1 = @()
        $rules1 = @()
    
    
    foreach ($entry1 in $2)
        {
            
            $properties = [ordered]@{
            RuleCollectionName = $entry1.RuleCollectionName;
            RulePriority = $entry1.RulePriority;
            ActionType = $entry1.ActionType;
            Name = $entry1.Name;
            protocols = $entry1.protocols -split ", ";
            SourceAddresses = $entry1.SourceAddresses -split ", ";
            DestinationAddresses = $entry1.DestinationAddresses -split ", ";
            SourceIPGroups = $entry1.SourceIPGroups -split ", ";
            DestinationIPGroups = $entry1.DestinationIPGroups -split ", ";
            DestinationPorts = $entry1.DestinationPorts -split ", ";
            DestinationFQDNs = $entry1.DestinationFQDNs -split ", ";
            }
        $obj1 = New-Object psobject -Property $properties
        $RulesfromCSV1 += $obj1
        
        }
    
    $RulesfromCSV1
     
    foreach ($entry1 in $RulesfromCSV1)
        {
            Write-Host $entry1.sourceAddresses
            $RuleParameter1 = @{
            Name = $entry1.Name;
            Protocol = $entry1.protocols           
            DestinationPort = $entry1.DestinationPorts
            
            }
            if ($entry1.SourceAddresses)
            {
                
                $RuleParameter1['sourceAddress'] = $entry1.SourceAddresses
            }
            if ($entry1.DestinationAddresses)
            {
                
                $RuleParameter1['DestinationAddress'] = $entry1.DestinationAddresses
            }
            if ($entry1.SourceIPGroups)
            {
                
                $RuleParameter1['SourceIpGroup'] = $entry1.SourceIPGroups
            }
            if ($entry1.DestinationIPGroups)
            {
                
                $RuleParameter1['DestinationIPGroups'] = $entry1.DestinationIPGroups
            }

        $rule1 = New-AzFirewallPolicyNetworkRule @RuleParameter1
        
            $NetworkRuleCollection = @{
            Name = $entry1.RuleCollectionName 
            
            Priority = $entry1.RulePriority
            ActionType = $entry1.ActionType
            Rule       = $rules1 += $rule1            
            
            }
        
        $NetworkRuleCategoryCollection = New-AzFirewallPolicyFilterRuleCollection @NetworkRuleCollection
        
        
        }
        
        $newrulecol = $target1.Properties.RuleCollection.Add($NetworkRuleCategoryCollection)
        
        
    }
    Set-AzFirewallPolicyRuleCollectionGroup -Name $colname1 -Priority 200 -RuleCollection $target1.Properties.RuleCollection -FirewallPolicyObject $targetfp
}

foreach($file in (Get-ChildItem ${savepath}\"*"-apprules.csv -File))

{

    
    # Change the folder where the CSV is located
    
    $readObj2 = import-csv $file
    $colname2 = $readObj2[0].psobject.properties.value[0]
    try {
        $target1 = Get-AzFirewallPolicyRuleCollectionGroup -Name $colname2 -ResourceGroupName $fprg -AzureFirewallPolicyName $fpname -ErrorAction Stop
    }
    catch {
        
        $targetrcg2 = New-AzFirewallPolicyRuleCollectionGroup -Name $colname2 -Priority 200 -FirewallPolicyObject $targetfp
        $target1 = Get-AzFirewallPolicyRuleCollectionGroup -Name $colname2 -ResourceGroupName $fprg -AzureFirewallPolicyName $fpname
    }
    
    $testcsv = $readObj2 | Select-Object -ExpandProperty RuleCollectionName -Unique
    ForEach ($item1 in $testcsv)
    {
        
        $2 = ($readObj2 | Where-Object {$_.RuleCollectionName -eq $item1})
        
        $RulesfromCSV2 = @()
        $rules2 = @()

    foreach ($entry2 in $2)
        {
            $properties = [ordered]@{
            RuleCollectionName = $entry2.RuleCollectionName;
            RulePriority = $entry2.RulePriority;
            ActionType = $entry2.ActionType;
            RuleCollectionType = $entry2.RuleCollectionType;
            Name = $entry2.Name;
            protocols = $entry2.protocols -split ", ";
            SourceAddresses = $entry2.SourceAddresses -split ", ";
            TargetFqdns = $entry2.TargetFqdns -split ", ";
            SourceIPGroups = $entry2.SourceIPGroups -split ", ";
            WebCategories = $entry2.WebCategories -split ", ";
            TargetUrls = $entry2.TargetUrls -split ", ";
        
            }
            
        $obj2 = New-Object psobject -Property $properties
        $RulesfromCSV2 += $obj2
        }
        
    $RulesfromCSV2

    $rules2 = @()
    foreach ($entry2 in $RulesfromCSV2)
        {
            $RuleParameter2 = @{
            Name = $entry2.Name;
            Protocol = $entry2.protocols            
            TargetFqdn = $entry2.TargetFqdns
            
            }
            if ($entry2.SourceAddresses)
            {
                
                $RuleParameter2['sourceAddress'] = $entry2.SourceAddresses
            }
            
            if ($entry2.SourceIPGroups)
            {
                
                $RuleParameter2['SourceIpGroup'] = $entry2.SourceIPGroups
            }
            
            
        $rule2 = New-AzFirewallPolicyApplicationRule @RuleParameter2
        $ApplicationRuleCollection = @{
            Name = $entry2.RuleCollectionName
            Priority = $entry2.RulePriority
            ActionType = $entry2.ActionType
            Rule       = $rules2 += $rule2
            }
        
            $ApplicationRuleCategoryCollection = New-AzFirewallPolicyFilterRuleCollection @ApplicationRuleCollection
        }

    # Create a network rule collection
    
    $newrulecol = $target1.Properties.RuleCollection.Add($ApplicationRuleCategoryCollection)
    # Deploy to created rule collection group
    
    }
    Set-AzFirewallPolicyRuleCollectionGroup -Name $colname2 -Priority 200 -RuleCollection $target1.Properties.RuleCollection -FirewallPolicyObject $targetfp
}

foreach($file in (Get-ChildItem ${savepath}\"*"-dnatrules.csv -File))

    {

        
        # Change the folder where the CSV is located
        
        $readObj3 = import-csv $file
        $colname3 = $readObj3[0].psobject.properties.value[0]
        try {
            $target1 = Get-AzFirewallPolicyRuleCollectionGroup -Name $colname3 -ResourceGroupName $fprg -AzureFirewallPolicyName $fpname -ErrorAction Stop
        }
        catch {
            
            $targetrcg3 = New-AzFirewallPolicyRuleCollectionGroup -Name $colname3 -Priority 200 -FirewallPolicyObject $targetfp
            $target1 = Get-AzFirewallPolicyRuleCollectionGroup -Name $colname3 -ResourceGroupName $fprg -AzureFirewallPolicyName $fpname
        }
        
        $testcsv = $readObj3 | Select-Object -ExpandProperty RuleCollectionName -Unique
        ForEach ($item1 in $testcsv)
        {
        
        $2 = ($readObj3 | Where-Object {$_.RuleCollectionName -eq $item1})
        
        $RulesfromCSV3 = @()
        $rules3 = @()


        foreach ($entry3 in $2)
        {
                $properties = [ordered]@{
                RuleCollectionName = $entry3.RuleCollectionName;
                RulePriority = $entry3.RulePriority;
                ActionType = $entry3.ActionType;
                RuleCollectionType = $entry3.RuleCollectionType;
                Name = $entry3.Name;
                protocols = $entry3.Protocols -split ", ";
                SourceAddresses = $entry3.SourceAddresses -split ", ";
                TranslatedAddress = $entry3.TranslatedAddress #-split ", ";
                SourceIPGroups = $entry3.SourceIPGroups -split ", ";
                TranslatedPort = $entry3.TranslatedPort #-split ", ";
                DestinationAddresses = $entry3.DestinationAddresses -split ", ";
                DestinationPorts = $entry3.DestinationPorts -split ", ";
            }
            $obj3 = New-Object psobject -Property $properties
            $RulesfromCSV3 += $obj3
        }
        
        $RulesfromCSV3
        
        $rules3 = @()
        foreach ($entry3 in $RulesfromCSV3)
        {
            $RuleParameter3 = @{
                Name = $entry3.Name;
                Protocol = $entry3.Protocols
                DestinationPort = $entry3.DestinationPorts
                TranslatedAddress = $entry3.TranslatedAddress
                TranslatedPort = $entry3.TranslatedPort
                
            }
            
            if ($entry3.SourceAddresses)
            {
                
                $RuleParameter3['sourceAddress'] = $entry3.SourceAddresses
            }
            if ($entry3.DestinationAddresses)
            {
                
                $RuleParameter3['DestinationAddress'] = $entry3.DestinationAddresses
            }
            if ($entry3.SourceIPGroups)
            {
                
                $RuleParameter3['SourceIpGroup'] = $entry3.SourceIPGroups
            }
            
            $rule3 = New-AzFirewallPolicyNatRule @RuleParameter3
                $NatRuleCollection = @{
                Name = $entry3.RuleCollectionName
                Priority = $entry3.RulePriority
                ActionType = $entry3.ActionType
                Rule       = $rules3 += $rule3
            }
            $NatRuleCategoryCollection = New-AzFirewallPolicyNatRuleCollection @NatRuleCollection
        }
        
        # Create a network rule collection
        
        $newrulecol = $target1.Properties.RuleCollection.Add($NatRuleCategoryCollection)
        # Deploy to created rule collection group
        
        }    
        Set-AzFirewallPolicyRuleCollectionGroup -Name $colname3 -Priority 200 -RuleCollection $target1.Properties.RuleCollection -FirewallPolicyObject $targetfp
    }
