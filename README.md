# Azfw policy rule backup and restore

The fwrulesbackup-v3.ps1 powershell script will take any Dnat, network and application rules and collection groups then save them to csv files for each collection group and rule type (for example, rulecollection1-netrules.csv, rulecollection1-apprules.csv). You will be prompted for the resource group and policy name to backup as well as the path to save to. The default path is "c:\temp".
The fwrulesrestore-split.ps1 script parses the files and creates the rules in the specified policy, there is also an option to create a new policy to restore to as well and asking to allow edits (replacing rules) versus just new additions. You will be prompted to create a new policy and for the resource group name and policy name to restore to.

The azfwruledump script just grabs all rules, collections, and collection groups and saves them to a single .CSV file.

Azfwruledumprestore uses the single dump file to restore/edit rules from, it also asks to allow edits (replacing rules) versus just new additions.
