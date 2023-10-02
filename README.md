# azfw policy rule backup and restore

These powershell scripts will take any Dnat, network and application rules and collection groups then save them to csv files for each collection group and rule type (for example, rulecollection1-netrules.csv, rulecollection1-apprules.csv). You will be prompted for the resource group and policy name to backup as well as the path to save to. The default path is "c:\temp".
The restore script parses the files and creates the rules in the specified policy, there is also an option to create a new policy to restore to. You will be prompted to create a new policy and for the resource group name and policy name to restore to.
