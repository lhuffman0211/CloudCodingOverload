#script will get site collection permissions, including site collection admins and users in SP groups.  Output to CSV file in current directory
#script could easily be modified to get report for all site collections in tenant

$currentPath = Get-CurrentScriptDirectory
$currentDateTime = Get-Date -format "yyyy-MM-d.hh-mm-ss"

#Path of Log File in Drive.
$currentLogPath = $currentPath + "\" + "CheckUserPermissionOnSite_"+ $currentDateTime +".txt"

#Permission Report
$csvPath = "$currentPath\Site_Permission_Report_" + $currentDateTime +".csv"
set-content $csvPath "SiteURL, Site Name, Item Type, UserName/GroupName, Permission, Group Members"
$siteUrl = ""

Connect-PnPOnline -Url $siteUrl -UseWebLogin
$web = Get-PnPWeb -Includes RoleAssignments
foreach($ra in $web.RoleAssignments) {
    $member = $ra.Member
    
    $itemType = "Site"
    $loginName = get-pnpproperty -ClientObject $member -Property Title
    
    $rolebindings = get-pnpproperty -ClientObject $ra -Property RoleDefinitionBindings
    write-host "User info: $($loginName) - $($rolebindings.Name)"
    
    $group = Get-PnPGroup -Identity $loginName | Select-Object Title,Users
    if ($group.Title -ne $null){
        $grpUsers = @()
        foreach ($user in $group.Users){
            $grpUsers += $user.Title + ";"
        }
        Write-Host "Groups users: $($grpUsers)"
    }
    write-host "$($Url),$($WebTitle),,$($loginName),$($rolebindings.Name),$($grpUsers)"
    add-content $csvPath "$($Url),$($WebTitle),$($itemType),,$($loginName),$($rolebindings.Name),$($grpUsers)"
    
}

#Get Site Collection Administrators
$siteAdmins = Get-PnPSiteCollectionAdmin
$grpSA = @()
foreach ($sa in $siteAdmins){
    Write-Host $sa.title
    $grpSA += $sa.Title + ";"
}

write-host "$($Url),$($WebTitle),,Site Collection Admin,$($sa.title),"
add-content $csvPath "$($Url),$($WebTitle),$($itemType),,Site Collection Admin,$($grpSA),"
Disconnect-PnPOnline