# vCenter Move VMs to Folder
# RJB - 20191127

# From PoSH CLI:  Set-ExecutionPolicy Unrestricted

function Get-FolderByPath{
    <#
     .SYNOPSIS Retrieve folders by giving a path
     .DESCRIPTION The function will retrieve a folder by it's path.
       The path can contain any type of leave (folder or datacenter).
     .NOTES
       Author: Luc Dekens .PARAMETER Path The path to the folder. This is a required parameter.
     .PARAMETER
       Path The path to the folder. This is a required parameter.
     .PARAMETER
       Separator The character that is used to separate the leaves in the path. The default is '/'
     .EXAMPLE
       PS> Get-FolderByPath -Path "Folder1/Datacenter/Folder2"
     .EXAMPLE
       PS> Get-FolderByPath -Path "Folder1>Folder2" -Separator '>'
    #>
     
      param(
      [CmdletBinding()]
      [parameter(Mandatory = $true)]
      [System.String[]]${Path},
      [char]${Separator} = '/'
      )
     
      process{
        if((Get-PowerCLIConfiguration).DefaultVIServerMode -eq "Multiple"){
          $vcs = $global:defaultVIServers
        }
        else{
          $vcs = $global:defaultVIServers[0]
        }
     
        foreach($vc in $vcs){
          $si = Get-View ServiceInstance -Server $vc
          $rootName = (Get-View -Id $si.Content.RootFolder -Property Name).Name
          foreach($strPath in $Path){
            $root = Get-Folder -Name $rootName -Server $vc -ErrorAction SilentlyContinue
            $strPath.Split($Separator) | %{
              $root = Get-Inventory -Name $_ -Location $root -Server $vc -ErrorAction SilentlyContinue
              if((Get-Inventory -Location $root -NoRecursion | Select -ExpandProperty Name) -contains "vm"){
                $root = Get-Inventory -Name "vm" -Location $root -Server $vc -NoRecursion
              }
            }
            $root | where {$_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]}|%{
              Get-Folder -Name $_.Name -Location $root.Parent -NoRecursion -Server $vc
            }
          }
        }
      }
    }


# Read Config
Get-Content -Path "config.ini" |
foreach-object `
    -begin {
        # Create an Hashtable
        $h=@{}
    } `
    -process {
        # Retrieve line with '=' and split them
        $k = [regex]::split($_,'=')
        if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True))
        {
            # Add the Key, Value into the Hashtable
            $h.Add($k[0], $k[1])
        }
    } `
    -end {Write-Output $h}

# Assign Variables
$vcenter = $h.Get_Item("vcenter")
$vcenteruser = $h.Get_Item("vcenteruser")
$vcenterpw = $h.Get_Item("vcenterpw")
$vmFolderMap = $h.Get_Item("foldermap")

# Load PowerCLI
# $o = Add-PSSnapin VMware.VimAutomation.Core
# $o = Get-Module -Name VMware* -ListAvailable | Import-Module
$o = Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

# Connect to vCenter Server
write-host "Connecting to vCenter Server $vcenter" -foreground green
$vc = Connect-VIServer $vcenter -User $vcenteruser -Password $vcenterpw

# Move VMs
Import-Csv $vmFolderMap -UseCulture | %{
    $vm = Get-VM -Name $_.VmName
    $folder = Get-FolderByPath -Path $_.FolderName
    Move-VM -VM $vm -InventoryLocation $folder
}
 
# Disconnect from vCenter Server
write-host "Disconnecting from vCenter Server $vcenter" -foreground green
$vc = Disconnect-VIServer -Server $vcenter -Confirm:$false

