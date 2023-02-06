#gets detailed report of lists/libraries/folders/ites/files with broken permissions, includes members of SP groups and sharing links
#outputs CSV file in current directory
#script could easily be modified to get report for all site collections in tenant

[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client")
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client.Runtime")
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.PowerShell")

function Get-CurrentScriptDirectory {
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}


#Logs and prints messages
function LogMessage([String] $Msg)
{
    Write-Host $Msg -ForegroundColor Green
    Write-Output "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") Message: $Msg" | Out-File -FilePath $currentLogPath -Append -Force
}
Function Invoke-LoadMethod() {
param(
   [Microsoft.SharePoint.Client.ClientObject]$Object = $(throw "Please provide a Client Object"),
   [string]$PropertyName
) 
   $ctx = $Object.Context
   $load = [Microsoft.SharePoint.Client.ClientContext].GetMethod("Load") 
   $type = $Object.GetType()
   $clientLoad = $load.MakeGenericMethod($type) 


   $Parameter = [System.Linq.Expressions.Expression]::Parameter(($type), $type.Name)
   $Expression = [System.Linq.Expressions.Expression]::Lambda(
            [System.Linq.Expressions.Expression]::Convert(
                [System.Linq.Expressions.Expression]::PropertyOrField($Parameter,$PropertyName),
                [System.Object]
            ),
            $($Parameter)
   )
   $ExpressionArray = [System.Array]::CreateInstance($Expression.GetType(), 1)
   $ExpressionArray.SetValue($Expression, 0)
   $clientLoad.Invoke($ctx,@($Object,$ExpressionArray))
}
$currentPath = Get-CurrentScriptDirectory
$currentDateTime = Get-Date -format "yyyy-MM-d.hh-mm-ss"

#Path of Log File in Drive.
$currentLogPath = $currentPath + "\" + "CheckUserPermissionOnSite_"+ $currentDateTime +".txt"

#Permission Report
$csvPath = "$currentPath\Site_Permission_Report_" + $currentDateTime +".csv"
set-content $csvPath "Site Name,List Name, Item Type, Item Title, UserName/GroupName, Permission, Group Members"


# Initialize client context-add own permissions
$siteUrl = ''

#Admin User Principal Name
$username = 'yourusername@tenant.onmicrosoft.com'

#Get Password as secure String
$password = Read-Host 'Enter Password' -AsSecureString

$credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($username,$password)

$clientContext = New-Object Microsoft.SharePoint.Client.ClientContext($siteUrl)
$clientContext.Credentials = $credentials

$Web = $clientContext.Web;
$clientContext.Load($Web)
$clientContext.ExecuteQuery()


$Url = $Web.Url;
$WebTitle = $Web.Title
Write-Host $Url;


$Lists = $Web.Lists
$clientContext.Load($Lists)
$clientContext.ExecuteQuery()


#Iterate through each list in a site   
ForEach($List in $Lists)
{
    #Get the List Name
    Write-host $List.Title
   
    $ExcludedLists = @("Access Requests", "Content and Structure Reports","Form Templates","Images", "Preservation Hold Library", "Site Assets", "Sharing Links", "SharePointHomeOrgLinks", "SharePointHomeCacheList", 
                             "Master Page Gallery", "List Template Gallery", "Site Collection Documents", "Site Collection Images","Style Library","Reusable Content","Workflow History","Workflow Tasks", "Form Templates", "Web Template Extensions", "Web Part Gallery", "User Information List", "Theme Gallery", "TaxonomyHiddenList", "SolutionGallery")
        
    If($ExcludedLists -notcontains $List.Title -and $List.Hidden -eq $false)
    {
        LogMessage(" InheritedPermissionList ")
        Invoke-LoadMethod -Object $List -PropertyName "HasUniqueRoleAssignments"
        $clientContext.ExecuteQuery()

         Write-Host $List.HasUniqueRoleAssignments
        

        if($List.HasUniqueRoleAssignments -eq $true)
        {

            $ListTitle = $List.Title
            Write-host $List.Title "has broken permission"

            $RoleAssignments = $List.RoleAssignments;
            $clientContext.Load($RoleAssignments)
            $clientContext.ExecuteQuery()

            foreach($ListRoleAssignment in $RoleAssignments)
            {

                $member = $ListRoleAssignment.Member
                $roleDef = $ListRoleAssignment.RoleDefinitionBindings

                $clientContext.Load($member)
                $clientContext.Load($roleDef)
                $clientContext.ExecuteQuery()
                $itemType = "Doc lib/List"
                     #Is it a User Account?
                 #if($roleDef -notcontains "Limited Access"){
                     if($ListRoleAssignment.Member.PrincipalType -eq "User")   
                     {
                         
                         Write-Host "Current user : " $ListRoleAssignment.Member.LoginName 
                         

                          $UserDisplayName = $ListRoleAssignment.Member.Title;
                          $ListUserPermissions=@()
                            foreach ($RoleDefinition  in $roleDef)
                            {
                                 $ListUserPermissions += $RoleDefinition.Name +";"
                            }
                            add-content $csvPath "$Url,$ListTitle,$itemType,,$UserDisplayName,$ListUserPermissions,"
                             #Send the Data to Log file
                             "$($List.ParentWeb.Url)/$($List.RootFolder.Url) `t List `t $($List.Title)`t Direct Permissions `t $($ListUserPermissions)" | Out-File UserAccessReport.csv -Append
                          
                    }
                    if($ListRoleAssignment.Member.PrincipalType -eq "SharePointGroup")   
                     {
                         
                         Write-Host "Current user : " $ListRoleAssignment.Member.LoginName 
                         

                          $GroupDisplayName = $ListRoleAssignment.Member.Title;
                          $ListUserPermissions=@()
                            foreach ($RoleDefinition  in $roleDef)
                            {
                                 $ListUserPermissions += $RoleDefinition.Name +";"
                            }
                            #Get the Group & Members of the group
                            $Group = $clientContext.web.SiteGroups.GetByName($GroupDisplayName)
                            $clientContext.Load($Group)
                            $GroupUsers = $Group.Users
                            $clientContext.Load($GroupUsers)
                            $clientContext.ExecuteQuery()
 
                            #Iterate through each User of the Group
                            $grpUserNames = @()
                            ForEach($User in $GroupUsers)
                            {
                                #get sharepoint online group members powershell
                                $User | Select Title
                                $grpUname = $User.Title.ToString()
                                $grpUserNames += $grpUname + ";"
                            }

                            write-host "$GroupDisplayName contains the following members: $($grpUserNames)"
                            add-content $csvPath "$Url,$ListTitle,$itemType,,$GroupDisplayName,$ListUserPermissions,$grpUserNames"
                            #Send the Data to Log file
                            "$($List.ParentWeb.Url)/$($List.RootFolder.Url) `t List `t $($List.Title)`t Direct Permissions `t $($ListUserPermissions)" | Out-File UserAccessReport.csv -Append
                          
                    }
                #}
            }


            $camlQuery = New-Object Microsoft.SharePoint.Client.CamlQuery
            $camlQuery.ViewXml ="<View Scope='RecursiveAll' />";
            $ListItems= $List.GetItems($camlQuery)
            $clientContext.Load($ListItems)
            $clientContext.ExecuteQuery()

            foreach($item in $ListItems)
            {
                $itemType = ""
                
                
                Write-Host "##############"
                if ($List.BaseType -eq "DocumentLibrary")
                {
                    $itemTitle = $item["FileLeafRef"]
                    $itemType = $item.FileSystemObjectType
                    Write-Host "Item:" $item["FileLeafRef"] ", Type:" $itemType
                    Write-Host "##############"
                }
                else
                {
                    $itemTitle = $item["Title"]
                    $itemType = "List Item"
                    Write-Host "Item:" $item["Title"] ", Type:" $itemType
                    
                }

                Invoke-LoadMethod -Object $item -PropertyName "HasUniqueRoleAssignments"
                $clientContext.ExecuteQuery()
                if ($item.HasUniqueRoleAssignments -eq $true)
                {
                  
                    $itemRoleAssignments = $item.RoleAssignments;
                    $clientContext.Load($itemRoleAssignments)
                    $clientContext.ExecuteQuery()

                    foreach($itemRoleAssignment in $itemRoleAssignments)
                    {

                        $Itemmember = $itemRoleAssignment.Member
                        $ItemroleDef = $itemRoleAssignment.RoleDefinitionBindings

                        $clientContext.Load($Itemmember)
                        $clientContext.Load($ItemroleDef)
                        $clientContext.ExecuteQuery()

                             #Is it a User Account?
                             if($itemRoleAssignment.Member.PrincipalType -eq "User")   
                             {
                                 #Is the current user is the user we search for?
                                 Write-Host "Current Item user : " $itemRoleAssignment.Member.LoginName 
                                 

                                  $UserDisplayName = $itemRoleAssignment.Member.Title;
                                  $ItemUserPermissions=@()
                                    foreach ($ItemRoleDefinition  in $ItemroleDef)
                                    {
                                         $ItemUserPermissions += $ItemRoleDefinition.Name +";"
                                    }
                                    add-content $csvPath "$Url,$ListTitle,$itemType,$itemTitle,$UserDisplayName,$ItemUserPermissions"
                                     #Send the Data to Log file
                                     "$($List.ParentWeb.Url)/$($List.RootFolder.Url) `t List `t $($List.Title)`t Direct Permissions `t $($ListUserPermissions)" | Out-File UserAccessReport.csv -Append
                                  
                            }
                            #Is it a User Account?
                             if($itemRoleAssignment.Member.PrincipalType -eq "SharePointGroup")   
                             {
                                 #Is the current user is the user we search for?
                                 Write-Host "Current Item user : " $itemRoleAssignment.Member.LoginName 
                                 $GroupDisplayName = $itemRoleAssignment.Member.Title;
                                  $ItemUserPermissions=@()
                                    foreach ($ItemRoleDefinition  in $ItemroleDef)
                                    {
                                         $ItemUserPermissions += $ItemRoleDefinition.Name +";"
                                    }
                                    #Get the Group & Members of the group
                                    $Group = $clientContext.web.SiteGroups.GetByName($GroupDisplayName)
                                    $clientContext.Load($Group)
                                    $GroupUsers = $Group.Users
                                    $clientContext.Load($GroupUsers)
                                    $clientContext.ExecuteQuery()
 
                                    #Iterate through each User of the Group
                                    $grpUserNames = @()
                                    ForEach($User in $GroupUsers)
                                    {
                                        #get sharepoint online group members powershell
                                        $User | Select Title
                                        $grpUname = $User.Title.ToString()
                                        $grpUserNames += $grpUname + ";"
                                    }

                                  
                                    
                                    add-content $csvPath "$Url,$ListTitle,$itemType,$itemTitle,$GroupDisplayName,$ItemUserPermissions,$grpUserNames"
                                     #Send the Data to Log file
                                     "$($List.ParentWeb.Url)/$($List.RootFolder.Url) `t List `t $($List.Title)`t Direct Permissions `t $($ListUserPermissions)" | Out-File UserAccessReport.csv -Append
                                      
                            }
                    }
                }

                #Write-Host $item.HasUniqueRoleAssignments
            }

            #Write-Host $ListItems.Count

        }
        else
        {

            Write-host $List.Title "has inherited permission"

        }
    }
}
