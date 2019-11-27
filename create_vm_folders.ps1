# vCenter Folder Creation
# RJB - 20191127

# From PoSH CLI:  Set-ExecutionPolicy Unrestricted

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
$datacenter = $h.Get_Item("datacenter")
$folders = $h.Get_Item("folders")

# Load PowerCLI
# $o = Add-PSSnapin VMware.VimAutomation.Core
# $o = Get-Module -Name VMware* -ListAvailable | Import-Module
$o = Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

# Connect to vCenter Server
write-host "Connecting to vCenter Server $vcenter" -foreground green
$vc = Connect-VIServer $vcenter -User $vcenteruser -Password $vcenterpw

# Create Folders
$dc = Get-Datacenter -Name $datacenter
$vmFolder = Get-View -id $dc.ExtensionData.VmFolder
Get-Content $folders | Foreach-Object{
    write-host "*** Creating VM folder $_ ***"
    $vmFolder.CreateFolder($_)
 }
 
# Disconnect from vCenter Server
write-host "Disconnecting from vCenter Server $vcenter" -foreground green
$vc = Disconnect-VIServer -Server $vcenter -Confirm:$false
