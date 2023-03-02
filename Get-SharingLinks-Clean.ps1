#replace $SiteURL variable

$SiteURL = ''

$SecurePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
$Cred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $username, $SecurePassword
 
#connect to sharepoint online site using powershell
$site = Connect-PnPOnline -Url $SiteURL -Interactive

#replace path for report
$currentPath = "C:\Temp"
$currentDateTime = Get-Date -format "yyyy-MM-d.hh-mm-ss"
$csvPath = "$currentPath\Sharing_Link_Report_" + $currentDateTime +".csv"
set-content $csvPath "Site Name,List Name, ItemType, Item Title, Sharing Link, User Name, Permission"

$array = @()
$listColl = Get-PnPList -Includes HasUniqueRoleAssignments | Where {$_.Hidden -eq $false}
foreach ($list in $listColl){
    $itemType= ""
    Write-Host "List Name: $($list.Title)"
    #add or remove any system lists or libraries
    $ExcludedLists = @("Access Requests", "Content and Structure Reports","Form Templates","Images", "Preservation Hold Library", "Site Assets", "Sharing Links", "SharePointHomeOrgLinks", "SharePointHomeCacheList", 
                             "Master Page Gallery", "List Template Gallery", "Site Collection Documents", "Site Collection Images","Style Library","Reusable Content","Workflow History","Workflow Tasks", "Form Templates", "Web Template Extensions", "Web Part Gallery", "User Information List", "Theme Gallery", "TaxonomyHiddenList", "SolutionGallery")
    
        If($ExcludedLists -notcontains $list.Title -and $list.HasUniqueRoleAssignments){

            Write-Host "$($list.Title) has broken permissions"
            $listItems = Get-PnPListItem -List $list -PageSize 2000
            foreach ($listItem in $listItems){
                $itemType = ""
                Get-PnPProperty -ClientObject $listItem -Property HasUniqueRoleAssignments, RoleAssignments

                if($listItem.HasUniqueRoleAssignments -eq $True) 
                {
                    foreach($roleAssignments in $listItem.RoleAssignments )  
                    {
                        Get-PnPProperty -ClientObject $roleAssignments -Property RoleDefinitionBindings, Member
       
                        $LoginName = $roleAssignments.Member.LoginName
                        $LoginTitle = $roleAssignments.Member.Title
                        $PrincipalType = $roleAssignments.Member.PrincipalType.ToString()
                        $Permission = ""
                        #Get the Permissions assigned to user 
                        foreach ($RoleDefinition  in $roleAssignments.RoleDefinitionBindings) 
                        { 
                            $itemType = ""
                            $Permission = $LoginName 
                            If($LoginName -like "SharingLinks*"){
                                $itemTitle = ""
                                Write-Host $Permission
                                if($list.BaseType -eq "DocumentLibrary"){
                                    $itemTitle = $listItem["FileLeafRef"]
                                    $itemType = $listItem.FileSystemObjectType 
                                }
                                else{
                                    $itemTitle = $listItem["Title"]
                                    $itemType =  "List Item"
                                }
                                $Users = Get-PnPProperty -ErrorAction SilentlyContinue -ClientObject $roleAssignments.Member -Property Users
                                if ($Users -ne $null) {
                                    $array = foreach ($user in $Users) {
                                        Write-host "$($list.Title), $($itemTitle), $($user.Title), $($RoleDefinition.Name)"
                                        add-content $csvPath "$($SiteURL), $($list.Title), $($itemType), $($itemTitle), $($Permission), $($user.Title), $($RoleDefinition.Name)"
                                        #"Site Name,List Name, Item Title, Sharing Link, User Name, Permission"
                                    }
                                }
                            }
                        }
        
                    }
                }
            }
        }
    
}
