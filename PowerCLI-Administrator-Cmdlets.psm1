<#
.Synopsis
   Create a new VDPortgroup based on an existing VDPortgroup
.DESCRIPTION
   Clone the settings of an existing VDPortgroup onto a new VDPortgroup. The VLAN tag is changed on the new entity
.EXAMPLE
   Clone-VDPortgroup -VDSwitch "myVDS" -Name "DPG_101_iSCSI_B" -VlanID "101" -ReferencePortgroup "DPG_100_iSCSI_A"
#>
function Clone-VDPortgroup
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # The name of the existing VDSwitch the new VDPortgroup will be attached to
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $VDSwitch,

        # The Vlan tag assigned to the new VDPortgroup
        [int]
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        $VlanId,

        # Name of the new VDPortgroup
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        $Name,

        # The reference VDPortgroup whose settings will be copied. Only the VLAN tag will change
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        $ReferencePortgroup
    )

    Begin
    {
    }
    Process
    {
        New-VDPortgroup -VDSwitch $VDSwitch -Name $Name -ReferencePortgroup $ReferencePortgroup
        Set-VDPortgroup -VDPortgroup $Name -VlanId $VlanId
    }
    End
    {
    }
}

<#
.Synopsis
   Get stats from a specified cluster
.DESCRIPTION
   Collect a number of stats from a cluster, including RAM and p/vCPU counts and the resources available after 1 or 2 node failures.
   Displays the statistics for both the cluster and per VMhost.

   Courtesy of Vamshi Meda (@medavamshi) via http://tenthirtyam.org/per-cluster-cpu-and-memory-utilization-and-capacity-metrics-with-powercli/
.EXAMPLE
   Get-ClusterStats -Cluster Cluster1
#>
function Get-ClusterStats
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        $Cluster

    )

    Begin
    {
    }
    Process
    {
        $ClusterName = Get-Cluster $Cluster
        $Clusters = Get-View -ViewType ComputeResource | ? Name -Like $ClusterName.Name
        $Clusters | % {
            $CurrentCluster               = $_
            $VMHostsView                  = $null
            $VMHostsView                  = Get-View $CurrentCluster.Host -Property Name, Hardware, Config
            $VMs                          = $ClusterName | Get-VM
            $HostCount                    = ($VMHostsView | Measure-Object).Count
            $VMCount                      = ($VMs | Measure-Object).Count
            $VMsPerHost                   = [math]::Round($VMCount / $HostCount, 1)
            $vCPU                         = ($VMs | Measure-Object -sum -Property NumCPU).Sum
            $allocatedRAM                 = ($VMs | Measure-Object -sum -Property MemoryGB).Sum
            $AvgRAMPerVM                  = [math]::Round($AllocatedRAM / $VMCount, 1)
            $pCPUSocket                   = ($VMHostsView | % { $_.Hardware.CPUInfo.NumCpuPackages } | Measure-Object -Sum).Sum
            $pCPUCore                     = ($VMHostsView | % { $_.Hardware.CPUInfo.NumCpuCores } | Measure-Object -Sum).Sum
            $vCPUPerpCPUCore              = [math]::Round($vCPU / $pCPUCore, 1)
            $NodeOne                      = Get-Cluster $Cluster | Get-VMHost | Select -First 1
            $NodeTwo                      = Get-Cluster $Cluster | Get-VMHost | Select -First 2
            $NodeOneTotalGB               = [math]::Round(($NodeOne | Measure-Object -Property MemoryTotalGB -Sum).Sum)
            $NodeTwoTotalGB               = [math]::Round(($NodeTwo | measure-object -Property MemoryTotalGB -Sum).Sum)
            $NodeOnepCPUCores             = [math]::Round(($NodeOne | Measure-Object -Property NumCPU -Sum).Sum)
            $NodeTwopCPUCores             = [math]::Round(($NodeTwo | Measure-Object -Property NumCPU -Sum).Sum)
            $pCores_OneNodeFailover       = $pCPUCore - $NodeOnepCPUCores
            $pCores_TwoNodeFailover       = $pCPUCore - $NodeTwopCPUCores
            $RAMGB                        = [math]::Round((Get-Cluster $Cluster | get-vmhost | % { $_ } | Measure-Object -property MemoryTotalGB -Sum).Sum)
            $RAM_OneNodeFailover          = [math]::Round($RAMGB - $NodeOneTotalGB)
            $RAM_TwoNodeFailover          = [math]::Round($RAMGB - $NodeTwoTotalGB)
            $RAMUsageGB                   = [math]::Round((Get-Cluster $Cluster | Get-VMHost | % { $_ } | Measure-Object -Property MemoryUsageGB -Sum).Sum)
            $RAMUsagePercent              = [math]::Round(($RAMUsageGB / $RAMGB) * 100)
            $RAMFreeGB                    = [math]::Round($RAMGB - $RAMUsageGB)
            $RAMReservedGB                = [math]::Round(($RAMGB / 100) * 15)
            $RAMAvailable                 = [math]::Round($RAMFreeGB - $RAMReservedGB)
            $RAMAvailable_OneNodeFailover = [math]::Round($RAMAvailable - $NodeOneTotalGB)
            $RAMAvailable_TwoNodeFailover = [math]::Round($RAMAvailable - $NodeTwoTotalGB)
            $vCPUperpCore_OneNodeFailover = [math]::Round($vCPU / $pCores_OneNodeFailover)
            $vCPUperpCore_TwoNodeFailover = [math]::Round($vCPU / $pCores_TwoNodeFailover)
            $NewVMs                       = [math]::Round($RAMAvailable / $AvgRAMPerVM)
            $NewVMs_OneNodeFailover       = [math]::Round($RAMAvailable_OneNodeFailover / $AvgRAMPerVM)
            $NewVMs_TwoNodeFailover       = [math]::Round($RAMAvailable_TwoNodeFailover / $AvgRAMPerVM)
 
            $ClusterInfo = "" | Select "Cluster Name", "Number of Hosts", "Number of VMs", "VMs per Host", "pCPUs (Socket)", "pCPU (Core)", "vCPU Count",
                                       "vCPU/pCPU Core", "vCPU/pCPU Core (1 node failure)", "vCPU/pCPU Core (2 node failure)", "RAM (GB)", "RAM (1 node failure)",
                                       "RAM (2 node failure)", "RAM Usage (%)", "RAM Usage (GB)", "RAM Free (GB)" , "RAM Reserved (GB, 15%)",
                                       "RAM Available for NEW VMs (GB)", "RAM Available for NEW VMs (1 node failure)", "RAM Available for NEW VMs (2 node failure)",
                                       "Average Allocated RAM/VM", "Est. # of new VMs based on RAM/VM", "Est. # of new VMs based on RAM/VM (1 node failure)",
                                       "Est. # of new VMs based on RAM/VM (2 node failure)"


            $ClusterInfo.'Cluster Name'                                       = $ClusterName.Name
            $ClusterInfo.'Number of Hosts'                                    = $HostCount
            $ClusterInfo.'Number of VMs'                                      = $VMCount
            $ClusterInfo.'VMs Per Host'                                       = $VMsPerHost
            $ClusterInfo.'pCPUs (Socket)'                                     = $pCPUSocket
            $ClusterInfo.'pCPU (Core)'                                        = $pCPUCore
            $ClusterInfo.'vCPU Count'                                         = $vCPU
            $ClusterInfo.'vCPU/pCPU Core'                                     = $vCPUperpCPUCore
            $ClusterInfo.'vCPU/pCPU Core (1 node failure)'                    = $vCPUperpCore_OneNodeFailover
            $ClusterInfo.'vCPU/pCPU Core (2 node failure)'                    = $vCPUperpCore_TwoNodeFailover
            $ClusterInfo.'RAM (GB)'                                           = $RAMGB
            $ClusterInfo.'RAM (1 node failure)'                               = $RAM_OneNodeFailover
            $ClusterInfo.'RAM (2 node failure)'                               = $RAM_TwoNodeFailover
            $ClusterInfo.'RAM Usage (%)'                                      = $RAMUsagePercent
            $ClusterInfo.'RAM Usage (GB)'                                     = $RAMUsageGB
            $ClusterInfo.'RAM Free (GB)'                                      = $RAMFreeGB
            $ClusterInfo.'RAM Reserved (GB, 15%)'                             = $RAMReservedGB
            $ClusterInfo.'RAM Available for NEW VMs (GB)'                     = $RAMAvailable
            $ClusterInfo.'RAM Available for NEW VMs (1 node failure)'         = $RAMAvailable_OneNodeFailover
            $ClusterInfo.'RAM Available for NEW VMs (2 node failure)'         = $RAMAvailable_TwoNodeFailover
            $ClusterInfo.'Average Allocated RAM/VM'                           = $AvgRAMPerVM
            $ClusterInfo.'Est. # of new VMs based on RAM/VM'                  = $NewVMs
            $ClusterInfo.'Est. # of new VMs based on RAM/VM (1 node failure)' = $NewVMs_OneNodeFailover
            $ClusterInfo.'Est. # of new VMs based on RAM/VM (2 node failure)' = $NewVMs_TwoNodeFailover
            $ClusterInfo
        }
 
        Get-Cluster $Cluster | Get-VMHost | % {
            $VMHost      = $_
            $VMHostView  = $VMHost | Get-View
            $VMHostModel = ($VMHostsView | % { $_.Hardware.SystemInfo } | Group-Object Model | Sort -Descending Count | Select -First 1).Name
            $VMs         = $VMHost | Get-VM 
            $RAMGB           = [math]::Round($VMHost.MemoryTotalGB)
            $RAMUsageGB      = [math]::Round($VMHost.MemoryUsageGB)
            $RAMFreeGB       = [math]::Round($RAMGB - $RAMUsageGB)
            $RAMReservedFree = [math]::Round(($RAMGB / 100) * 15)
            $RAMAvailable    = [math]::Round($RAMFreegb - $RAMReservedFree)
            $PercentRAMUsed       = [math]::Round(($RAMUsageGB / $RAMGB) * 100)
            $VMCount     = ($VMs | Measure-Object).Count
            $CPUCount    = ($VMs | Measure-Object -Sum NumCPU).Sum
            $CPUCores    = $VMHostView.Hardware.cpuinfo.NumCPUCores
            $vCPUPerCore = $CPUCount / $CPUCores

            $VMHostInfo = "" | Select VMhost, Model, Sockets, Cores, Threads, VMs, vCPU, 'vCPU/Core', "RAM (GB)", "RAM Usage (GB)",
                                      "RAM Free (GB)", "RAM Usage (%)", "15% RAM Reservation (GB)", "Available RAM (GB)"
            $VMHostInfo.VMhost = $VMHost.Name
            $VMHostInfo.Model  = $VMhostModel
            $VMHostInfo.Sockets = $VMHostView.Hardware.cpuinfo.NumCPUPackages
            $VMHostInfo.Cores = $VMHostView.Hardware.cpuinfo.NumCPUCores
            $VMHostInfo.Threads = $VMHostView.Hardware.cpuinfo.NumCPUThreads
            $VMHostInfo.VMs = $VMCount
            $VMHostInfo.vCPU = $CPUCount
            $VMHostInfo.'vCPU/Core' = $vCPUPerCore
            $VMHostInfo.'RAM (GB)' = $RAMGB
            $VMHostInfo.'RAM Usage (GB)' = $RAMUsageGB
            $VMHostInfo.'RAM Free (GB)' = $RAMFreeGB
            $VMHostInfo.'Ram Usage (%)' = $PercentRAMused
            $VMHostInfo.'15% RAM Reservation (GB)' = $RAMreservedFree
            $VMHostInfo.'Available RAM (GB)' = $RAMavailable
            $VMHostInfo
        } | Sort VMhost | ft -AutoSize * | Out-String -Width 1024
    }
    End
    {
    }
}

<#
.Synopsis
   Edit ESXI VMs with v10 virtual hardware
.DESCRIPTION
   Provide an alternative GUI to editing VMs using v10 virtual hardware if the vSphere Web Client is unavailable

   Courtesy of @HostileCoding via http://hostilecoding.blogspot.com/2014/03/vmware-powercli-gui-to-edit-vm-hardware.html
.EXAMPLE
   Edit-v10VMs
#>
function Edit-v10VMs
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
    )

    Begin
    {
    }
    Process
    {
		##################BEGIN FUNCTIONS


		function connectServer {
			try {

				$connect = Connect-VIServer -Server $serverTextBox.Text -User $usernameTextBox.Text -Password $passwordTextBox.Text

				$buttonConnect.Enabled = $false #Disable controls once connected
				$serverTextBox.Enabled = $false
				$usernameTextBox.Enabled = $false
				$passwordTextBox.Enabled = $false
				$buttonDisconnect.Enabled = $true #Enable Disconnect button

				getVmHosts #Populate DropDown list with all hosts connected (if vCenter)

				$HostDropDownBox.Enabled=$true
				
				
				$outputTextBox.text = "`nCurrently connected to $($serverTextBox.Text)" #If connection is successfull let user know it

				}

				catch {
				
				$outputTextBox.text = "`nSomething went wrong connecting to server!!"
			
			}

		}

		function disconnectServer {

			try {

				Disconnect-VIServer -Confirm:$false -Force:$true

				$buttonConnect.Enabled = $true #Enable login controls once disconnected
				$serverTextBox.Enabled = $true
				$usernameTextBox.Enabled = $true
				$passwordTextBox.Enabled = $true
				$buttonDisconnect.Enabled = $false #Disable Disconnect button
				
				$HostDropDownBox.Items.Clear() #Remove all items from DropDown boxes
				$HostDropDownBox.Enabled=$false #Disable DropDown boxes since they are empty
				$VmDropDownBox.Items.Clear()
				$VmDropDownBox.Enabled=$false
				$HardDiskDropDownBox.Items.Clear()
				$HardDiskDropDownBox.Enabled=$false
				$NetworkNameDropDownBox.Items.Clear()
				$NetworkNameDropDownBox.Enabled=$false
				$networkLabelDropDownBox.Items.Clear()
				$networkLabelDropDownBox.Enabled=$false
				$NetworkAdapterDropDownBox.Items.Clear()
				$NetworkAdapterDropDownBox.Enabled=$false
				$numVCpuTextBox.Text = ""
				$numVCpuTextBox.Enabled=$false
				$memSizeGBTextBox.Text = ""
				$memSizeGBTextBox.Enabled=$false
				$diskSizeGBTextBox.Text = ""
				$diskSizeGBTextBox.Enabled=$false
				$macAddressTextBox.Text = ""
				$macAddressTextBox.Enabled=$false
				$wolEnabled.Checked = $false
				$wolEnabled.Enabled = $false
				$connectedEnabled.Checked = $false
				$connectedEnabled.Enabled = $false
				$AddNewHardwareDropDownBox.Items.Clear()
				$AddNewHardwareDropDownBox.Enabled=$false
				$buttonAddHardware.Enabled = $false
				$newDiskSizeGBTextBox.Text = ""
				$newDiskSizeGBTextBox.Enabled=$false
				$independentEnabled.Enabled = $false
				$connectedAtPoweron.Checked = $false
				$connectedAtPoweron.Enabled = $false
				$adapterTypeDropDownBox.Items.Clear()
				$adapterTypeDropDownBox.Enabled = $false
				$networkLabelDropDownBox.Items.Clear()
				$networkLabelDropDownBox.Enabled = $false
				
				
				
				$outputTextBox.text = "`nSuccessfully disconnected from $($serverTextBox.Text)" #If disconnection is successfull let user know it

			}

			catch {
			
				$outputTextBox.text = "`nSomething went wrong disconnecting from server!!"
			
			}

		}

		function getVmHosts {

			try {

				$vmhosts = Get-VMHost | Where-Object {$_.PowerState -eq "PoweredOn" -and $_.ConnectionState -eq "Connected"} # Returns only powered On VmHosts

				foreach ($vm in $vmhosts) {
				
					$HostDropDownBox.Items.Add($vm.Name) #Add Hosts to DropDown List
					
				}    

			}

			catch {
			
				$outputTextBox.text = "`nSomething went wrong getting VMHosts!!"
			
			}

		}

		function getVmsOnHost {

			try {
			
				$outputTextBox.text = "`nGetting Virtual Machines with Hardware Version 10 on VMHost: $($HostDropDownBox.SelectedItem.ToString())"
				
				$v10vms = Get-VM | Where-Object {$_.Version -eq "v10" -and $_.VMHost -eq $(Get-VMHost | Where-Object {$_.Name -eq $HostDropDownBox.SelectedItem.ToString()})} #Returns hardware v10 VMs

				foreach ($vm in $v10vms) {
				
					$VmDropDownBox.Items.Add($vm.Name) #Add VMs to DropDown List
				
				}

				$VmDropDownBox.Enabled=$true

			}

			catch {
			
				$outputTextBox.text = "`nSomething went wrong getting VMHosts!!"
			
			}

		}

		function getDisks {

			try {
			
				$HardDiskDropDownBox.Enabled = $true #Enable dropdownbox
				
				$harddisks = Get-HardDisk -VM $VmDropDownBox.SelectedItem.ToString()
				
				foreach ($disk in $harddisks) {
				
					$HardDiskDropDownBox.Items.Add($disk.Name) #Add Hosts to DropDown List
					
				}
				
				$HardDiskDropDownBox.SelectedItem = $harddisks.Name #Pre-Select Hard Disk
				
			}
			catch {
			
			   $outputTextBox.text = "`nSomething went wrong getting VmHardDisks!!"
			   
			}
		}

		function getSelectedDiskSize {

			try {
			
				$diskSizeGBTextBox.text = "" #Clear
				
				$diskSizeGBTextBox.Enabled = $true

				$harddisks = Get-HardDisk -VM $VmDropDownBox.SelectedItem.ToString() -Name $HardDiskDropDownBox.SelectedItem.ToString()
				
				$diskSizeGBTextBox.text = $harddisks.CapacityGB
				
			}
			catch{
			   
			   $outputTextBox.text = "`nSomething went wrong getting SelectedDiskSize!!"
			   
			}
		}

		function getNetwork {

			try {
			
				$NetworkAdapterDropDownBox.Enabled = $true #Enable DropDown Box
				
				$wolEnabled.Enabled = $true
				$connectedEnabled.Enabled = $true
				
				$NetworkAdapterDropDownBox.Items.Clear() #Remove all items from DropDown Box since it may be dirtied by previous executions
				
				$networks= Get-NetworkAdapter -VM $VmDropDownBox.SelectedItem.ToString()
				
				foreach ($network in $networks) {
					
					$NetworkAdapterDropDownBox.Items.Add($network.Name) #Add Networks to DropDown List
				
				}
				
				$NetworkAdapterDropDownBox.SelectedItem = $networks.Name #Pre-Select Network
				
				if ($network.WakeOnLanEnabled -match "True") { #If WOL enabled
				
					$wolEnabled.Checked = $true
				
				}
				else {
				
					$wolEnabled.Checked = $false
				
				}
				
				if (-Not ($network.ConnectionState -match "NotConnected")) { #If connected
				
					$connectedEnabled.Checked = $true
				
				}
				else {
				
					$connectedEnabled.Checked = $false
				
				}
			
			}
			catch {
			
			   $outputTextBox.text = "`nSomething went wrong getting Networks!!"
			   
			}
		}

		function getSelectedNetworkName {
		
			try {
			
				$NetworkNameDropDownBox.Enabled = $true #Enable DropDown Box
				
				#$macAddressTextBox.Enabled = $true
			
				$NetworkNameDropDownBox.Items.Clear() #Remove all items from DropDown Box since it may be dirtied by previous executions
				$networkLabelDropDownBox.Items.Clear()
				
				$networks = Get-VirtualPortGroup -VMHost $HostDropDownBox.SelectedItem.ToString()
				
				foreach ($network in $networks) {
					$NetworkNameDropDownBox.Items.Add($network.Name) #Add Networks to DropDown List
					$networkLabelDropDownBox.Items.Add($network.Name)
				}
				
				$adapterNetwork = Get-NetworkAdapter -VM $VmDropDownBox.SelectedItem.ToString() -Name $NetworkAdapterDropDownBox.SelectedItem.ToString() #Get networks used by the adapter VM
				
				$NetworkNameDropDownBox.SelectedItem = $adapterNetwork.NetworkName #Pre-select by default the VM Network used by the selected VM
				
				$macAddressTextBox.text = $adapterNetwork.MacAddress
				
				$Label15.Text = $adapterNetwork.Type
				
			}
			catch {
			
			   $outputTextBox.text = "`nSomething went wrong getting SelectedNetworkName!!"
			   
			}
		}

		function getAddNewHardware {

			try {
				
				if ($AddNewHardwareDropDownBox.SelectedItem -match "Hard Disk") { #Add new Hard Disk
				
					if ($independentEnabled.Checked -eq $true) { #Independent
					
						if ($persistentRadioButton.Checked -eq $true) { #Independent Persistent
					
							$persistence = "IndependentPersistent"
						
						}
						elseif ($nonPersistentRadioButton.Checked  -eq $true) { #Independent Non Persistent
						
							$persistence = "IndependentNonPersistent"
						
						}
					
					}
					elseif ($independentEnabled.Checked -eq $false) { #Persistent
					
						$persistence = "Persistent"
					
					}
					
					Get-VM -Name $VmDropDownBox.SelectedItem.ToString() | New-HardDisk -CapacityGB $newDiskSizeGBTextBox.Text -Persistence $persistence -Confirm:$false
				
				}
				elseif ($AddNewHardwareDropDownBox.SelectedItem.ToString() -match "Network Adapter") { #Add new Network Adapter
				
					if ($connectedAtPoweron.Checked -eq $true) { #Connected at Poweron
					
						$startpoweron = $true
					
					}
					elseif ($connectedAtPoweron.Checked -eq $false) {
					
						$startpoweron = $false
					
					}
					if ($adapterTypeDropDownBox.SelectedItem.ToString() -match "E1000") { #E1000
					
						$adaptertype = "e1000"
					
					}
					elseif ($adapterTypeDropDownBox.SelectedItem.ToString() -match "VMXNET3") { #VMXNET3
					
						$adaptertype = "vmxnet3"
					
					}
					elseif ($adapterTypeDropDownBox.SelectedItem.ToString() -match "E1000E") { #E1000E
					
						$adaptertype = "EnhancedVmxnet"
					
					}
				
					Get-VM -Name $VmDropDownBox.SelectedItem.ToString() | New-NetworkAdapter -NetworkName $networkLabelDropDownBox.SelectedItem.ToString() -StartConnected:$startpoweron -Type $adaptertype
				
				}
			
				getVmConfigs #Refresh data in Text Boxes
			
			}
			catch {
			
			   $outputTextBox.text = "`nSomething went wrong getting AddNewHardware!!"
			
			}
		}

		function getVmConfigs {

			try {
			
				$outputTextBox.text = "`nGetting configs for VM: $($VmDropDownBox.SelectedItem.ToString())"
			
				$numVCpuTextBox.Enabled = $true #Enable TextBoxes
				$memSizeGBTextBox.Enabled = $true
				$buttonSetVm.Enabled = $true
				
				$AddNewHardwareDropDownBox.Enabled=$true #Enable Add new Hardware
				
				$HardDiskDropDownBox.Items.Clear() #Remove all items from GroupBox since it may be dirtied by previous executions
				$NetworkNameDropDownBox.Items.Clear()
				$NetworkAdapterDropDownBox.Items.Clear()
				$AddNewHardwareDropDownBox.Items.Clear()
				$connectedAtPoweron.Checked = $false
				$connectedAtPoweron.Enabled = $false
				$adapterTypeDropDownBox.Items.Clear()
				$adapterTypeDropDownBox.Enabled = $false
				$networkLabelDropDownBox.Items.Clear()
				$networkLabelDropDownBox.Enabled = $false
				$independentEnabled.Enabled = $false
				$persistentRadioButton.Enabled = $false
				$nonPersistentRadioButton.Enabled = $false	
				
				$numVCpuTextBox.Text = "";
				$memSizeGBTextBox.Text = "";
				$diskSizeGBTextBox.Text = ""
				$macAddressTextBox.Text = ""
				$newDiskSizeGBTextBox.Text = ""
				$newDiskSizeGBTextBox.Enabled = $false

				$VmInfos = Get-VM -Name $VmDropDownBox.SelectedItem.ToString()

				$numVCpuTextBox.text = $VmInfos.NumCPU
				$memSizeGBTextBox.text = $VmInfos.MemoryGB

				getDisks
				
				getNetwork
				
				$hwsList=@("Hard Disk","Network Adapter") #Populate DropDownBox. By calling it in this method list is populated even if a reconnection occurs.

				foreach ($hw in $hwsList) {
				
					$AddNewHardwareDropDownBox.Items.Add($hw)
					
				}
				
				$typeList=@("E1000","VMXNET3", "E1000E")

				foreach ($types in $typeList) {
				
					$adapterTypeDropDownBox.Items.Add($types)
					
				}
			
			}
			catch{
			
			   $outputTextBox.text = "`nSomething went wrong getting VmConfigs!!"
			   
			}

		}

		function setVmConfigs {

			try {
			
			$numVCpu = $numVCpuTextBox.Text -as [int] #Convert values to integer
			$memSizeGB = $memSizeGBTextBox.Text -as [int]
			$diskSizeGB = $diskSizeGBTextBox.Text -as [int]
			
			Get-VM -Name $VmDropDownBox.SelectedItem.ToString() | Set-VM -NumCpu $numVCpu -MemoryGB $memSizeGB -Confirm:$false 
			
			if ($HardDiskDropDownBox.Text.Length -gt 0) {
			
				Get-HardDisk -VM $VmDropDownBox.SelectedItem.ToString() -Name $HardDiskDropDownBox.SelectedItem.ToString() | Set-HardDisk -CapacityGB $diskSizeGB -Confirm:$false
				
			}
			else {

				$outputTextBox.text = "`nTo change HardDisk size you must first select one virtual disk!!"
				
			}
			
			if (($NetworkAdapterDropDownBox.Text.Length -gt 0) -and ($NetworkNameDropDownBox.Text.Length -gt 0)) {
				
				if ($wolEnabled.Checked -eq $true) { #Set Wake On LAN
				
					$wol = $true
				
				}
				elseif ($wolEnabled.Checked -eq $false) {
				
					$wol = $false
				
				}
				
				if ($connectedEnabled.Checked -eq $true) { #Set Connected
				
					$connected = $true
				
				}
				elseif ($connectedEnabled.Checked -eq $false) {
				
					$connected = $false
				
				}
				
				#Set-NetworkAdapter -MacAddress $macAddressTextBox.Text
				
				Set-NetworkAdapter -NetworkAdapter (Get-NetworkAdapter -VM $VmDropDownBox.SelectedItem.ToString() -Name $NetworkAdapterDropDownBox.SelectedItem.ToString()) -NetworkName $NetworkNameDropDownBox.SelectedItem.ToString() -WakeOnLan $wol -Connected $connected -Confirm:$false
				
			}
			else {

				$outputTextBox.text = "`nTo change Network Adapter settings you must first select one!!"
				
			}
			
			getVmConfigs #Refresh data in Text Boxes
				
			}
			catch {
			
			   $outputTextBox.text = "`nSomething went wrong setting VmConfigs!!"
			
			}
		}

		##################END FUNCTIONS

		[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
		[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 

		##################Main Form Definition
		
		$main_form = New-Object System.Windows.Forms.Form 
		$main_form.Text = "Edit VM Hardware v10" #Form Title
		$main_form.Size = New-Object System.Drawing.Size(425,815) 
		$main_form.StartPosition = "CenterScreen"

		$main_form.KeyPreview = $True
		$main_form.Add_KeyDown({if ($_.KeyCode -eq "Escape")

		{$main_form.Close()}})

		##################GroupBox Definition
		
		$groupBox1 = New-Object System.Windows.Forms.GroupBox
		$groupBox1.Location = New-Object System.Drawing.Size(10,5)

		$groupBox1.size = New-Object System.Drawing.Size(190,200) #Width, Heigth
		$groupBox1.text = "Connect to vCenter or ESXi host:"

		$main_form.Controls.Add($groupBox1)


		$groupBox2 = New-Object System.Windows.Forms.GroupBox
		$groupBox2.Location = New-Object System.Drawing.Size(10,215)

		$groupBox2.size = New-Object System.Drawing.Size(390,60) #Width, Heigth
		$groupBox2.text = "Hosts Operations:"

		$main_form.Controls.Add($groupBox2)


		$groupBox3 = New-Object System.Windows.Forms.GroupBox
		$groupBox3.Location = New-Object System.Drawing.Size(10,285)

		$groupBox3.size = New-Object System.Drawing.Size(390,410) #Width, Heigth
		$groupBox3.text = "VMs Operations:"

		$main_form.Controls.Add($groupBox3)


		$groupBox4 = New-Object System.Windows.Forms.GroupBox
		$groupBox4.Location = New-Object System.Drawing.Size(10,700)

		$groupBox4.size = New-Object System.Drawing.Size(390,70) #Width, Heigth
		$groupBox4.text = "Output:"

		$main_form.Controls.Add($groupBox4)
		
		$groupBox5 = New-Object System.Windows.Forms.GroupBox
		$groupBox5.Location = New-Object System.Drawing.Size(210,5)

		$groupBox5.size = New-Object System.Drawing.Size(190,200) #Width, Heigth
		$groupBox5.text = "Instructions:"

		$main_form.Controls.Add($groupBox5)


		##################Label Definition
		
		$Label1 = New-Object System.Windows.Forms.Label
		$Label1.Location = New-Object System.Drawing.Point(10, 20)
		$Label1.Size = New-Object System.Drawing.Size(120, 14)
		$Label1.Text = "IP Address or FQDN:"
		$groupBox1.Controls.Add($Label1) #Member of GroupBox1

		$Label2 = New-Object System.Windows.Forms.Label
		$Label2.Location = New-Object System.Drawing.Point(10, 70)
		$Label2.Size = New-Object System.Drawing.Size(120, 14)
		$Label2.Text = "Username:"
		$groupBox1.Controls.Add($Label2) #Member of GroupBox1

		$Label3 = New-Object System.Windows.Forms.Label
		$Label3.Location = New-Object System.Drawing.Point(10, 120)
		$Label3.Size = New-Object System.Drawing.Size(120, 14)
		$Label3.Text = "Password:"
		$groupBox1.Controls.Add($Label3) #Member of GroupBox1
		
		$Label4 = New-Object System.Windows.Forms.Label
		$Label4.Location = New-Object System.Drawing.Point(10, 15)
		$Label4.Size = New-Object System.Drawing.Size(120, 14)
		$Label4.Text = "Select Host:"
		$groupBox2.Controls.Add($Label4) #Member of GroupBox2
		
		$Label5 = New-Object System.Windows.Forms.Label
		$Label5.Location = New-Object System.Drawing.Point(10, 15)
		$Label5.Size = New-Object System.Drawing.Size(120, 14)
		$Label5.Text = "Select VM:"
		$groupBox3.Controls.Add($Label5) #Member of GroupBox3
		
		$Label6 = New-Object System.Windows.Forms.Label
		$Label6.Location = New-Object System.Drawing.Point(10, 55)
		$Label6.Size = New-Object System.Drawing.Size(90, 14)
		$Label6.Text = "Num vCPU:"
		$groupBox3.Controls.Add($Label6) #Member of GroupBox3
		
		$Label7 = New-Object System.Windows.Forms.Label
		$Label7.Location = New-Object System.Drawing.Point(200, 55)
		$Label7.Size = New-Object System.Drawing.Size(160, 14)
		$Label7.Text = "Memory size in GB:"
		$groupBox3.Controls.Add($Label7) #Member of GroupBox3
		
		$Label8 = New-Object System.Windows.Forms.Label
		$Label8.Location = New-Object System.Drawing.Point(10, 95)
		$Label8.Size = New-Object System.Drawing.Size(80, 14)
		$Label8.Text = "Hard Disk:"
		$groupBox3.Controls.Add($Label8) #Member of GroupBox3
		
		$Label9 = New-Object System.Windows.Forms.Label
		$Label9.Location = New-Object System.Drawing.Point(10, 15)
		$Label9.Size = New-Object System.Drawing.Size(170, 180)
		$Label9.Text = "1) Connect to vCenter or ESXi host `r`n`r`n2) Select host and get v10 VMs `r`n`r`n3) Select VM `r`n`r`n4) Modify VM settings`r`n`r`n5) Apply Changes `r`n`r`n6) If needed add new hardware`r`n`r`n`Developed by @HostileCoding"
		$groupBox5.Controls.Add($Label9) #Member of GroupBox3
		
		$Label10 = New-Object System.Windows.Forms.Label
		$Label10.Location = New-Object System.Drawing.Point(200, 95)
		$Label10.Size = New-Object System.Drawing.Size(120, 14)
		$Label10.Text = "Hard Disk size in GB:"
		$groupBox3.Controls.Add($Label10) #Member of GroupBox3
		
		$Label11 = New-Object System.Windows.Forms.Label
		$Label11.Location = New-Object System.Drawing.Point(10, 135)
		$Label11.Size = New-Object System.Drawing.Size(120, 14)
		$Label11.Text = "Network Adapter:"
		$groupBox3.Controls.Add($Label11) #Member of GroupBox3
		
		$Label12 = New-Object System.Windows.Forms.Label
		$Label12.Location = New-Object System.Drawing.Point(200, 135)
		$Label12.Size = New-Object System.Drawing.Size(120, 14)
		$Label12.Text = "Network Name:"
		$groupBox3.Controls.Add($Label12) #Member of GroupBox3
		
		$Label13 = New-Object System.Windows.Forms.Label
		$Label13.Location = New-Object System.Drawing.Point(10, 175)
		$Label13.Size = New-Object System.Drawing.Size(120, 14)
		$Label13.Text = "MAC Address:"
		$groupBox3.Controls.Add($Label13) #Member of GroupBox3
		
		$Label14 = New-Object System.Windows.Forms.Label
		$Label14.Location = New-Object System.Drawing.Point(200, 175)
		$Label14.Size = New-Object System.Drawing.Size(40, 14)
		$Label14.Text = "Type:"
		$groupBox3.Controls.Add($Label14) #Member of GroupBox3
		
		$Label15 = New-Object System.Windows.Forms.Label
		$Label15.Location = New-Object System.Drawing.Point(240, 175)
		$Label15.Size = New-Object System.Drawing.Size(100, 14)
		$groupBox3.Controls.Add($Label15) #Member of GroupBox3
		
		$Label16 = New-Object System.Windows.Forms.Label
		$Label16.Location = New-Object System.Drawing.Point(10, 240)
		$Label16.Size = New-Object System.Drawing.Size(120, 14)
		$Label16.Text = "Add New Hardware:"
		$groupBox3.Controls.Add($Label16) #Member of GroupBox3
		
		$Label17 = New-Object System.Windows.Forms.Label
		$Label17.Location = New-Object System.Drawing.Point(10, 280)
		$Label17.Size = New-Object System.Drawing.Size(120, 14)
		$Label17.Text = "Hard Disk size in GB:"
		$groupBox3.Controls.Add($Label17) #Member of GroupBox3
		
		$Label18 = New-Object System.Windows.Forms.Label
		$Label18.Location = New-Object System.Drawing.Point(10, 320)
		$Label18.Size = New-Object System.Drawing.Size(120, 14)
		$Label18.Text = "Adapter Type:"
		$groupBox3.Controls.Add($Label18) #Member of GroupBox3
		
		$Label19 = New-Object System.Windows.Forms.Label
		$Label19.Location = New-Object System.Drawing.Point(200, 320)
		$Label19.Size = New-Object System.Drawing.Size(120, 14)
		$Label19.Text = "Network Label:"
		$groupBox3.Controls.Add($Label19) #Member of GroupBox3

		##################Button Definition
		
		$buttonConnect = New-Object System.Windows.Forms.Button
		$buttonConnect.add_click({connectServer})
		$buttonConnect.Text = "Connect"
		$buttonConnect.Top=170
		$buttonConnect.Left=10
		$groupBox1.Controls.Add($buttonConnect) #Member of GroupBox1

		$buttonDisconnect = New-Object System.Windows.Forms.Button
		$buttonDisconnect.add_click({disconnectServer})
		$buttonDisconnect.Text = "Disconnect"
		$buttonDisconnect.Top=170
		$buttonDisconnect.Left=100
		$buttonDisconnect.Enabled = $false #Disabled by default
		$groupBox1.Controls.Add($buttonDisconnect) #Member of GroupBox1

		$buttonvGetVms = New-Object System.Windows.Forms.Button
		$buttonvGetVms.Size = New-Object System.Drawing.Size(180,25)

		$buttonvGetVms.add_click({getVmsOnHost})
		$buttonvGetVms.Text = "Get VMs for selected Host"
		$buttonvGetVms.Left=200
		$buttonvGetVms.Top=25
		$groupBox2.Controls.Add($buttonvGetVms) #Member of GroupBox2
		
		$buttonSetVm = New-Object System.Windows.Forms.Button
		$buttonSetVm.Size = New-Object System.Drawing.Size(370,20)

		$buttonSetVm.add_click({setVmConfigs})
		$buttonSetVm.Text = "Apply Changes"
		$buttonSetVm.Left=10
		$buttonSetVm.Top=215
		$buttonSetVm.Enabled = $false #Disabled by default
		$groupBox3.Controls.Add($buttonSetVm) #Member of GroupBox3
		
		$buttonAddHardware = New-Object System.Windows.Forms.Button
		$buttonAddHardware.Size = New-Object System.Drawing.Size(370,20)

		$buttonAddHardware.add_click({getAddNewHardware})
		$buttonAddHardware.Text = "Add Hardware"
		$buttonAddHardware.Left=10
		$buttonAddHardware.Top=380
		$buttonAddHardware.Enabled = $false #Disabled by default
		$groupBox3.Controls.Add($buttonAddHardware) #Member of GroupBox3

		##################CheckBox Definition	
			
		$wolEnabled = New-Object System.Windows.Forms.checkbox
		$wolEnabled.Location = New-Object System.Drawing.Size(200, 190)
		$wolEnabled.Size = New-Object System.Drawing.Size(100,20)
		$wolEnabled.Enabled = $false
		$wolEnabled.Checked = $false
		$wolEnabled.Text = "Wake on LAN"
		$groupBox3.Controls.Add($wolEnabled) #Member of GroupBox3
		
		$connectedEnabled = New-Object System.Windows.Forms.checkbox
		$connectedEnabled.Location = New-Object System.Drawing.Size(300, 190)
		$connectedEnabled.Size = New-Object System.Drawing.Size(80,20)
		$connectedEnabled.Enabled = $false
		$connectedEnabled.Checked = $false
		$connectedEnabled.Text = "Connected"
		$groupBox3.Controls.Add($connectedEnabled) #Member of GroupBox3
		
		$independentEnabled = New-Object System.Windows.Forms.checkbox
		$independentEnabled.Location = New-Object System.Drawing.Size(200, 280)
		$independentEnabled.Size = New-Object System.Drawing.Size(150,20)
		$independentEnabled.Enabled = $false
		$independentEnabled.Checked = $false
		$independentEnabled.Text = "Independent"
		$groupBox3.Controls.Add($independentEnabled) #Member of GroupBox3
		
		$independentEnabled.Add_CheckStateChanged({ #Checkbox Enabled
		
			if ($independentEnabled.Checked) {
			
				$persistentRadioButton.Enabled = $true
				$nonPersistentRadioButton.Enabled = $true
					
			}
			else {
			
				$persistentRadioButton.Enabled = $false
				$nonPersistentRadioButton.Enabled = $false
			
			}
			
		})
		
		$connectedAtPoweron = New-Object System.Windows.Forms.checkbox
		$connectedAtPoweron.Location = New-Object System.Drawing.Size(10, 360)
		$connectedAtPoweron.Size = New-Object System.Drawing.Size(150,20)
		$connectedAtPoweron.Enabled = $false
		$connectedAtPoweron.Checked = $false
		$connectedAtPoweron.Text = "Connect at poweron"
		$groupBox3.Controls.Add($connectedAtPoweron) #Member of GroupBox3
			
		##################RadioButton Definition

		$persistentRadioButton = New-Object System.Windows.Forms.RadioButton

		$persistentRadioButton.Location = new-object System.Drawing.Point(200,300)

		$persistentRadioButton.size = New-Object System.Drawing.Size(80,20)

		$persistentRadioButton.Checked = $true

		$persistentRadioButton.Enabled = $false
		$persistentRadioButton.Text = "Persistent"
		$groupBox3.Controls.Add($persistentRadioButton)
		
		$nonPersistentRadioButton = New-Object System.Windows.Forms.RadioButton
		$nonPersistentRadioButton.Location = new-object System.Drawing.Point(280,300)
		$nonPersistentRadioButton.size = New-Object System.Drawing.Size(100,20)
		$nonPersistentRadioButton.Checked = $false
		$nonPersistentRadioButton.Enabled = $false
		$nonPersistentRadioButton.Text = "Non Persistent"
		$groupBox3.Controls.Add($nonPersistentRadioButton)

		##################TextBox Definition

		$serverTextBox = New-Object System.Windows.Forms.TextBox

		$serverTextBox.Location = New-Object System.Drawing.Size(10,40) #Left, Top, Right, Bottom
		$serverTextBox.Size = New-Object System.Drawing.Size(165,20)
		$groupBox1.Controls.Add($serverTextBox) #Member of GroupBox1

		$usernameTextBox = New-Object System.Windows.Forms.TextBox

		$usernameTextBox.Location = New-Object System.Drawing.Size(10,90)
		$usernameTextBox.Size = New-Object System.Drawing.Size(165,20)

		$groupBox1.Controls.Add($usernameTextBox) #Member of GroupBox1

		$passwordTextBox = New-Object System.Windows.Forms.MaskedTextBox #Password TextBox
		$passwordTextBox.PasswordChar = '*'
		$passwordTextBox.Location = New-Object System.Drawing.Size(10,140)
		$passwordTextBox.Size = New-Object System.Drawing.Size(165,20)
		$groupBox1.Controls.Add($passwordTextBox) #Member of GroupBox1
		
		$numVCpuTextBox = New-Object System.Windows.Forms.TextBox
		$numVCpuTextBox.Location = New-Object System.Drawing.Size(10,70)
		$numVCpuTextBox.Size = New-Object System.Drawing.Size(180,20)
		$numVCpuTextBox.Enabled=$false

		$groupBox3.Controls.Add($numVCpuTextBox) #Member of GroupBox3
		
		$memSizeGBTextBox = New-Object System.Windows.Forms.TextBox
		$memSizeGBTextBox.Location = New-Object System.Drawing.Size(200,70)
		$memSizeGBTextBox.Size = New-Object System.Drawing.Size(180,20)
		$memSizeGBTextBox.Enabled=$false

		$groupBox3.Controls.Add($memSizeGBTextBox) #Member of GroupBox3
		
		$diskSizeGBTextBox = New-Object System.Windows.Forms.TextBox
		$diskSizeGBTextBox.Location = New-Object System.Drawing.Size(200,110)
		$diskSizeGBTextBox.Size = New-Object System.Drawing.Size(180,20)
		$diskSizeGBTextBox.Enabled=$false

		$groupBox3.Controls.Add($diskSizeGBTextBox) #Member of GroupBox3
		
		$macAddressTextBox = New-Object System.Windows.Forms.TextBox
		$macAddressTextBox.Location = New-Object System.Drawing.Size(10,190)
		$macAddressTextBox.Size = New-Object System.Drawing.Size(180,20)
		$macAddressTextBox.Enabled=$false

		$groupBox3.Controls.Add($macAddressTextBox) #Member of GroupBox3
		
		$newDiskSizeGBTextBox = New-Object System.Windows.Forms.TextBox
		$newDiskSizeGBTextBox.Location = New-Object System.Drawing.Size(10,295)
		$newDiskSizeGBTextBox.Size = New-Object System.Drawing.Size(180,20)
		$newDiskSizeGBTextBox.Enabled=$false

		$groupBox3.Controls.Add($newDiskSizeGBTextBox) #Member of GroupBox3

		$outputTextBox = New-Object System.Windows.Forms.TextBox

		$outputTextBox.Location = New-Object System.Drawing.Size(10,20)
		$outputTextBox.Size = New-Object System.Drawing.Size(370,40)
		$outputTextBox.MultiLine = $True

		$outputTextBox.ReadOnly = $True
		$outputTextBox.ScrollBars = "Vertical"

		$groupBox4.Controls.Add($outputTextBox) #Member of groupBox4

		##################DropDownBox Definition

		$VmDropDownBox = New-Object System.Windows.Forms.ComboBox
		$VmDropDownBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList #Disable user input in ComboBox
		$VmDropDownBox.Location = New-Object System.Drawing.Size(10,30)

		$VmDropDownBox.Size = New-Object System.Drawing.Size(370,20)

		$VmDropDownBox.DropDownHeight = 200
		$VmDropDownBox.Enabled=$false

		$groupBox3.Controls.Add($VmDropDownBox)
		
		$handler_VmDropDownBox_SelectedIndexChanged= { #DropDownBox SelectedIndexChanged Handler
			try {
				if ($VmDropDownBox.Text.Length -gt 0) {
				   getVmConfigs
				}
			}
			catch {
			}
		}
		$VmDropDownBox.add_SelectedIndexChanged($handler_VmDropDownBox_SelectedIndexChanged)

		$HostDropDownBox = New-Object System.Windows.Forms.ComboBox
		$HostDropDownBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList #Disable user input in ComboBox
		$HostDropDownBox.Location = New-Object System.Drawing.Size(10,30)

		$HostDropDownBox.Size = New-Object System.Drawing.Size(180,20)

		$HostDropDownBox.DropDownHeight = 200
		$HostDropDownBox.Enabled=$false

		$groupBox2.Controls.Add($HostDropDownBox)
		
		$HardDiskDropDownBox = New-Object System.Windows.Forms.ComboBox
		$HardDiskDropDownBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList #Disable user input in ComboBox
		$HardDiskDropDownBox.Location = New-Object System.Drawing.Size(10,110)

		$HardDiskDropDownBox.Size = New-Object System.Drawing.Size(180,20)

		$HardDiskDropDownBox.DropDownHeight = 200
		$HardDiskDropDownBox.Enabled=$false

		$groupBox3.Controls.Add($HardDiskDropDownBox)
		
		$handler_HardDiskDropDownBox_SelectedIndexChanged= { #DropDownBox SelectedIndexChanged Handler
			try {
				if ($HardDiskDropDownBox.Text.Length -gt 0) {
				   getSelectedDiskSize
				}
			}
			catch {
			}
		}
		$HardDiskDropDownBox.add_SelectedIndexChanged($handler_HardDiskDropDownBox_SelectedIndexChanged)
		
		$NetworkAdapterDropDownBox = New-Object System.Windows.Forms.ComboBox
		$NetworkAdapterDropDownBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList #Disable user input in ComboBox
		$NetworkAdapterDropDownBox.Location = New-Object System.Drawing.Size(10,150)

		$NetworkAdapterDropDownBox.Size = New-Object System.Drawing.Size(180,20)

		$NetworkAdapterDropDownBox.DropDownHeight = 200
		$NetworkAdapterDropDownBox.Enabled=$false

		$groupBox3.Controls.Add($NetworkAdapterDropDownBox)
		
		$handler_NetworkAdapterDropDownBox_SelectedIndexChanged= { #DropDownBox SelectedIndexChanged Handler
			try{
				if ($NetworkAdapterDropDownBox.Text.Length -gt 0) {
				   getSelectedNetworkName
				}
			}
			catch {	
			}
		}
		$NetworkAdapterDropDownBox.add_SelectedIndexChanged($handler_NetworkAdapterDropDownBox_SelectedIndexChanged)
		
		$NetworkNameDropDownBox = New-Object System.Windows.Forms.ComboBox
		$NetworkNameDropDownBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList #Disable user input in ComboBox
		$NetworkNameDropDownBox.Location = New-Object System.Drawing.Size(200,150)

		$NetworkNameDropDownBox.Size = New-Object System.Drawing.Size(180,20)

		$NetworkNameDropDownBox.DropDownHeight = 200
		$NetworkNameDropDownBox.Enabled=$false

		$groupBox3.Controls.Add($NetworkNameDropDownBox)
		
		$AddNewHardwareDropDownBox = New-Object System.Windows.Forms.ComboBox
		$AddNewHardwareDropDownBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList #Disable user input in ComboBox
		$AddNewHardwareDropDownBox.Location = New-Object System.Drawing.Size(10,255)

		$AddNewHardwareDropDownBox.Size = New-Object System.Drawing.Size(370,20)

		$AddNewHardwareDropDownBox.DropDownHeight = 200
		$AddNewHardwareDropDownBox.Enabled=$false

		$groupBox3.Controls.Add($AddNewHardwareDropDownBox)
		
		$handler_AddNewHardwareDropDownBox_SelectedIndexChanged= { #DropDownBox SelectedIndexChanged Handler
			try {
				if ($AddNewHardwareDropDownBox.Text.Length -gt 0) {
				
					$buttonAddHardware.Enabled = $true
					
					if ($AddNewHardwareDropDownBox.SelectedItem.ToString() -match "Hard Disk") {
					
						$newDiskSizeGBTextBox.Enabled = $true	#Enable components
						$independentEnabled.Enabled = $true
						
						$connectedAtPoweron.Enabled = $false	#Disable components
						$adapterTypeDropDownBox.Enabled = $false
						$networkLabelDropDownBox.Enabled = $false
						
					}
					elseif ($AddNewHardwareDropDownBox.SelectedItem.ToString() -match "Network Adapter") {
					
						$connectedAtPoweron.Enabled = $true		#Enable components
						$adapterTypeDropDownBox.Enabled = $true
						$networkLabelDropDownBox.Enabled = $true
					
						$newDiskSizeGBTextBox.Enabled = $false	#Disable components
						$independentEnabled.Enabled = $false
						$persistentRadioButton.Enabled = $false
						$nonPersistentRadioButton.Enabled = $false
						
						$adapterTypeDropDownBox.Items.Clear() #Clear DropDown Box since it could be dirtied
						
						$typeList=@("E1000","VMXNET3", "E1000E")

						foreach ($types in $typeList) {
							$adapterTypeDropDownBox.Items.Add($types)
						}
						
					}					
				}
			}catch{	
			}
		}
		$AddNewHardwareDropDownBox.add_SelectedIndexChanged($handler_AddNewHardwareDropDownBox_SelectedIndexChanged)	
		
		$adapterTypeDropDownBox = New-Object System.Windows.Forms.ComboBox
		$adapterTypeDropDownBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList #Disable user input in ComboBox
		$adapterTypeDropDownBox.Location = New-Object System.Drawing.Size(10,335)

		$adapterTypeDropDownBox.Size = New-Object System.Drawing.Size(180,20)

		$adapterTypeDropDownBox.DropDownHeight = 200
		$adapterTypeDropDownBox.Enabled=$false

		$groupBox3.Controls.Add($adapterTypeDropDownBox)

		$networkLabelDropDownBox = New-Object System.Windows.Forms.ComboBox
		$networkLabelDropDownBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList #Disable user input in ComboBox
		$networkLabelDropDownBox.Location = New-Object System.Drawing.Size(200,335)

		$networkLabelDropDownBox.Size = New-Object System.Drawing.Size(180,20)

		$networkLabelDropDownBox.DropDownHeight = 200
		$networkLabelDropDownBox.Enabled=$false

		$groupBox3.Controls.Add($networkLabelDropDownBox)	

		##################Show Form

		$main_form.Add_Shown({$main_form.Activate()})
		[void] $main_form.ShowDialog()
    }
    End
    {
    }
}

<#
.Synopsis
   Clone a VM using VAAI
.DESCRIPTION
   Clone a VM using VAAI a specified number of times for stress testing. Optionally, disable VAAI or enable logging of the IP received by a VM after booting.
   Cloned VMs receive the name of the original plus the string "-clone-<number>".

   The default number of clones created is 2.

   Courtesy of @StevenPoitras and Andre Leibovici via http://myvirtualcloud.net/?p=5924
.EXAMPLE
   Clone-VM -Name Win7 -Cluster Lab -Count 400

   Create 400 copies of a VM named "Win7" in the cluster "Lab"
.EXAMPLE
   Get-VM | Select -First 1 | Clone-VM -Cluster Lab -Count 100 -DisableVAAI -WaitForIPs

   Using the Get-VM cmdlet, select the first VM returned and clone it 100 times without using VAAI into the cluster "Lab". Upon completion, log the IP each VM received.
#>
function Clone-VM
{
    [CmdletBinding()]
    [OutputType([int])]
	Param(
        # Reference VM to clone
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        $Name,

        # Number of times to clone the VM
        [int]
        $Count = 2,

		[Parameter(Mandatory=$True)]
        [String]
        $Cluster,

        # Disable VAAI during cloning operation.
		[switch]
        $DisableVAAI,

        # Log VM IPs after booted. Defaults to false (disabled)
		[switch]
        $WaitForIPs = $false
	)
    Begin
    {
		$Cluster = Get-Cluster | where {$_.name -eq $Cluster}
		$Hosts = Get-VMHost -Location $Cluster
		$SourceVM = Get-VM -Location $Cluster | where {$_.name -like $Name } | Get-View
        $VMPattern = $SourceVM.Name + "-clone"
		$CloneFolder = $SourceVM.parent
		$CloneSpec = New-Object Vmware.Vim.VirtualMachineCloneSpec
		$CloneSpec.Location = New-Object Vmware.Vim.VirtualMachineRelocateSpec
		$CloneSpec.Location.Transform = [Vmware.Vim.VirtualMachineRelocateTransformation]::flat
		if ($DisableVAAI) {
			Write-Output "Cloning VM $Name without VAAI."
			$CloneSpec.Location.DiskMoveType = [Vmware.Vim.VirtualMachineRelocateDiskMoveOptions]::createNewChildDiskBacking
			$CloneSpec.Snapshot = $SourceVM.Snapshot.CurrentSnapshot
		}
		else {
			Write-Output "Cloning VM $Name using VAAI."
			$CloneSpec.Location.DiskMoveType = [Vmware.Vim.VirtualMachineRelocateDiskMoveOptions]::moveAllDiskBackingsAndAllowSharing
		}

		Write-Output "Creating $Count VMs from VM: $Name"

		# Create VMs.
		$Global:CreationStartTime = Get-Date
		for($i=1; $i -le $Count; $i++) {
			$NewVMName = "$VMPattern-$i"
			$CloneSpec.Location.host = $Hosts[$i % $Hosts.count].Id
            Write-Output "Starting clone operation for VM $i, $VMPattern-$i."
			$SourceVM.CloneVM_Task( $CloneFolder, $NewVMName, $CloneSpec ) | Out-Null
		}

		# Wait for all VMs to finish being cloned.
		$VMs = Get-VM -Location $Cluster -Name "$VMPattern-*"
		while($VMs.count -lt $Count) {
			$VMCount = $VMs.count
			Write-Output "$VMCount of $Count clones created so far, waiting for all VMs to finish..."
			Start-Sleep -s 5
			$VMs = Get-VM -Location $Cluster -Name "$VMPattern-*"
		}

		Write-Output "Powering on VMs"
		# Power on newly created VMs.
		$Global:PowerOnStartTime = Get-Date
		Start-VM -RunAsync "$VMPattern-*" | Out-Null

		$BootedClones = New-Object System.Collections.ArrayList
		#$waiting_clones = New-Object System.Collections.ArrayList
		while($BootedClones.count -lt $Count) {
			# Wait until all VMs are booted.
			$Clones = Get-VM -Location $Cluster -Name "$VMPattern-*"
			foreach ($Clone in $Clones){
				if((-not $BootedClones.contains($clone.Name)) -and ($Clone.PowerState -eq "PoweredOn")) {
					if($WaitForIPs) {
						$IP = $Clone.Guest.IPAddress[0]
						if ($IP){
							Write-Output "$Clone.Name started with ip: $IP"
						}
					}
					$BootedClones.add($Clone.Name) | Out-Null
				}
			}
		}

		$Global:TotalRuntime = $(Get-Date) - $Global:CreationStartTime
		$Global:PowerOnRuntime = $(Get-Date) - $Global:PowerOnStartTime

		Write-Output "Total time elapsed to boot $Count VMs: $Global:PowerOnRuntime"
		Write-Output "Total time elapsed to clone and boot $Count VMs: $Global:TotalRuntime"
    }
    Process
    {
    }
    End
    {
    }
}

<#
.Synopsis
   Remove VMs created by Clone-VM cmdlet
.DESCRIPTION
   Remove VMs created by Clone-VM cmdlet. Provide the name of the base VM used by Clone-VM, the '-clone-*' string will be appended automatically.

   Courtesy of @StevenPoitras and Andre Leibovici via http://myvirtualcloud.net/?p=5924
.EXAMPLE
   Unclone-VM -Name "Test" -Count 2
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Unclone-VM
{
    [CmdletBinding()]
    [OutputType([int])]
	Param(
        # Reference VM to clone
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Name,

        # Disable confirmation of Stop-VM and Remove-VM commands
        [switch]
        $NoConfirmation
	)
    Begin
    {
        # For easier reading of the operations, we want the opposite of the $NoConfirmation switch
        $Confirmation = ! $NoConfirmation

        $Pattern = "$Name-clone-*"
        $Count = (Get-VM -Location $Cluster -Name $Pattern).count
        if ($Count -lt 1) {
            Write-Output "No VMs were found matching the pattern '$Pattern'. Exiting."
            Break;
        }

        Write-Output "Found $Count VMs matching the pattern '$Pattern'. Cleaning up clones."
		Write-Output "Powering off VMs."
		Stop-VM -RunAsync -Confirm:$Confirmation "$Name-*" | Out-Null
		Write-Output "Deleting VMs."
		Remove-VM -RunAsync -Confirm:$Confirmation -DeletePermanently:$true "$Name-*" | Out-Null
		Write-Output "Cleanup complete."
    }
    Process
    {
    }
    End
    {
    }
}

<#
.Synopsis
   Deploy VMs based on a specified Template
.DESCRIPTION
   Using a specified Template, deploy a number of VMs using sequential IP addresses. Requires an existing 
   OSCustomizationSpec of the correct OS type that will be customized per Clone. The Spec should include
   correct DNS settings.

   Based on http://pelicanohintsandtips.wordpress.com/2014/03/13/creating-multiple-virtual-machines-with-powercli/
.EXAMPLE
   Deploy-Template -Template CentOS-Template -StartingIP "192.168.0.10" -Netmask "255.255.255.0" -DefaultGateway "192.168.0.1"
   -Number 5 -Prefix "CentOS-Test" -Folder "CentOS-Test" -Datastore "Datastore1" -Cluster "Lab" -OSCustomizationSpec "Windows Static"
.EXAMPLE
   Get-Template | Select -First 1 | Deploy-Template -StartingIP "192.168.0.10" -Netmask "255.255.255.0" -DefaultGateway "192.168.0.1"
   -Number 5 -Prefix "CentOS-Test" -Folder "CentOS-Test" -Datastore "Datastore1" -Cluster "Lab" -OSCustomizationSpec "Windows Static"
#>
function Deploy-Template
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Template the deployed VM is based on
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        $Template,

        # Param2 help description
        [Parameter(Mandatory=$true)]
        [string]
        $StartingIP,
		
		# Netmask in A.B.C.D notation
        [Parameter(Mandatory=$true)]
		[string]
		$Netmask,
		
		# Default Gateway IP
        [Parameter(Mandatory=$true)]
		[string]
		$DefaultGateway,
		
		# Number of VMs to deploy from the template VM
        [Parameter(Mandatory=$true)]
		[int]
		$Number,
		
		# Prefix of the newly created VMs
        [Parameter(Mandatory=$true)]
		[string]
		$Prefix,
		
		# Folder on which VMs will be deployed
        [Parameter(Mandatory=$true)]
		[string]
		$Folder,
		
		# Datastore on which VMs will be deployed
        [Parameter(Mandatory=$true)]
		[string]
		$Datastore,
		
		# Cluster on which VMs will be deployed
        [Parameter(Mandatory=$true)]
		[string]
		$Cluster,
		
		# OS Customization Specification name
        [Parameter(Mandatory=$true)]
		[string]
		$OSCustomizationSpec,

        # DNS server(s). Only required for Windows Servers
        [System.Array]
        $DNS

    )

    Begin
    {
    }
    Process
    {
        # Deploy VMs
        $IP = $StartingIP
        For ($Count=1; $Count -le $Number; $Count++) {
			$Name = $Prefix + $Count
            Get-OSCustomizationSpec -Name $OSCustomizationSpec | New-OSCustomizationSpec -Name $Name -Type NonPersistent | Out-Null
            if ($DNS -ne $null) {
    			Get-OSCustomizationNICMapping -OSCustomizationSpec $Name | Set-OSCustomizationNICMapping -IPMode UseStaticIP -IPAddress $IP -SubNetMask $Netmask -DefaultGateway $DefaultGateway -Dns $DNS | Out-Null
            }
            else {
    			Get-OSCustomizationNICMapping -OSCustomizationSpec $Name | Set-OSCustomizationNICMapping -IPMode UseStaticIP -IPAddress $IP -SubNetMask $Netmask -DefaultGateway $DefaultGateway | Out-Null
            }
            New-VM -Name $Name -Template $Template -Datastore $Datastore -ResourcePool $Cluster -Location $Folder -OSCustomizationSpec $Name -RunAsync | Out-Null
            $NextIP = $IP.Split(“.”)
            $NextIP[3] = [int]$NextIP[3]+1
            $IP = $NextIP -Join“.”
        }

        # Sleep for a short period to ensure tasks have time to start
        Start-Sleep -s 10

        # Start VMs
        For ($Count=1; $Count -le $Number; $Count++) {
            $Name = $Prefix + $Count
            While ((Get-VM $Name).Version -eq "Unknown") {
				Write-Output “Waiting to start $Name”
                Start-Sleep -s 10
			}
            Start-VM $Name
        }
	}
    End
    {
    }
}

<#
.Synopsis
   Email report of outstanding snapshots
.DESCRIPTION
   For snapshots that are over the specified $Retention period, email the owner or $MailDefault to clean up their snapshots.

   Note that there is a limit of 32 event collectors allowed. If you cancel this cmdlet while running, you may exhaust this
   limit and you will need to restart your PowerShell instance to run it again.
.EXAMPLE
   Send-SnapshotReports -MailFrom you@example.com -MailDefault default@example.com -SMTPRelay localhost

   Using the curently connected vSphere server, sends mail from you@example.com to default@example.com, using localhost as a relay, for snapshots over the default
   retention age of 14 days. Mail will be sent using 'localhost' as the relay. The default retention timeframe is 14 days, only snapshots over this age will generate emails.

.EXAMPLE
   Send-SnapshotReports -MailFrom you@example.com -MailDefault default.example.com -LookupOwner -SMTPrelay smtp.example.com -Retention 3

   Using the curently connected vSphere server, sends mail from you@example.com to either default@example.com or the snapshot owner, using smtp.example.com as a relay,
   for snapshots over the retention age of 3 days. Ownership of snapshots is determined by correlating the vSphere SSO username with Active Directory. The PowerCLI
   host must be in the same domain for this to work (or a domain that happens to have the same email on record for the username).
.EXAMPLE
   Send-SnapshotReports -vSphereServer esxi -Credential $vSphereCredential -MailFrom you@example.com -MailDefault default.example.com -LookupOwner -SMTPrelay smtp.example.com -Retention 3

   Connects to the vSphereServer of 'esxi', sends mail from you@example.com to either default@example.com or the snapshot owner, using smtp.example.com as a relay,
   for snapshots over the retention age of 3 days. Ownership of snapshots is determined by correlating the vSphere SSO username with Active Directory. The PowerCLI
   host must be in the same domain for this to work (or a domain that happens to have the same email on record for the username).

   The additional $Credential provided is ideal for unattended operations, where there is no interactive shell available. Note that when used interactively, this
   flag will connect to the vSphere server before it begins and disconnect when it is done.
#>
function Send-SnapshotReports
{
    Param
    (
        # vSphere server hostname or address. This can be an ESXi host or a vCenter host.
        [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=0,
                   ParameterSetName='vSphere Server')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("host")] 
        [Alias("vcenter")]
        $vSphereServer = "vcenter",

        # Param2 help description
        [Parameter(Mandatory=$true)]
        [string]
        $MailFrom,

        # Default email address for Snapshots with no creator
        [Parameter(Mandatory=$true)]
        [String]
        $MailDefault,

        # SMTP Mail Relay
        [Parameter(Mandatory=$true)]
        $SMTPRelay,

        # Attempt to send emails to the designated owner, based on Active Directory/SSO correlation
        [switch]
        $LookupOwner = $false,

        # Retention timeframe, in days
        $Retention = 14,

        # Credential to use for unattended operation
        $Credential
    )

    Begin
    {
        Add-PSSnapin VMware.VimAutomation.Core -ea "SilentlyContinue"
    }
    Process
    {
        function Find-OwnerEmail ($Username) {
            $MailDestination = $MailDefault
            if (($Username -ne "Unknown Owner") -and ($LookupOwner)) {
                $User = (($Username.split("\"))[1])
                $Root = [ADSI]""
                $Filter = ("(&(objectCategory=user)(samAccountName=$User))")
                $DS = new-object system.DirectoryServices.DirectorySearcher($Root, $Filter)
                $DS.PageSize = 1000
                $MailDestination = ($DS.FindOne()).Properties.mail
                Write-Debug "Found an email target of '$MailDestination' for '$Username'."
            }
            else {
                Write-Debug "Using default destination '$MailDefault'."
            }
            return $MailDestination
        }

        function Get-SnapshotTree {
    	    param($tree, $target)

	        $found = $null
	        foreach($elem in $tree){
    		    if($elem.Snapshot.Value -eq $target.Value){
		    	    $found = $elem
	    		    continue
    		    }
	        }
	        if($found -eq $null -and $elem.ChildSnapshotList -ne $null){
    		    $found = Get-SnapshotTree $elem.ChildSnapshotList $target
    	    }

    	    return $found
        }

        function Get-SnapshotExtra ($snap) {
            $guestName = $snap.VM # The name of the guest
            $tasknumber = 999     # Window size of the Task collector
            $taskMgr = Get-View TaskManager

            # Create hash table. Each entry is a create snapshot task
            $report = @{}

            $filter = New-Object VMware.Vim.TaskFilterSpec
            $filter.Time = New-Object VMware.Vim.TaskFilterSpecByTime
            $filter.Time.beginTime = (($snap.Created).AddDays(-$Retention))
            $filter.Time.timeType = "startedTime"
            # Added filter to only view for the selected VM entity. Massive speed up.
            # Entity name check could be removed in line 91.
            $filter.Entity = New-Object VMware.Vim.TaskFilterSpecByEntity
            $filter.Entity.Entity = $snap.VM.ExtensionData.MoRef

            $collectionImpl = Get-View ($taskMgr.CreateCollectorForTasks($filter))

            $dummy = $collectionImpl.RewindCollector
            $collection = $collectionImpl.ReadNextTasks($tasknumber)
            while($collection -ne $null){
                $collection | Where-Object {$_.DescriptionId -eq "VirtualMachine.createSnapshot" -and $_.State -eq "success" -and $_.EntityName -eq $guestName} | Foreach-Object {
                    $row = New-Object PsObject
                    $row | Add-Member -MemberType NoteProperty -Name User -Value $_.Reason.UserName
                    $vm = Get-View $_.Entity
                    if($vm -ne $null){ 
                        $snapshot = Get-SnapshotTree $vm.Snapshot.RootSnapshotList $_.Result
                        if($snapshot -ne $null){
                            $key = $_.EntityName + "&" + ($snapshot.CreateTime.ToString())
                            $report[$key] = $row
                         }
                    }
                }
                $collection = $collectionImpl.ReadNextTasks($tasknumber)
            }
            $collectionImpl.DestroyCollector()

            # Get the guest's snapshots and add the user
            $snapshotsExtra = $snap | % {
                $key = $_.vm.Name + "&" + ($_.Created.ToUniversalTime().ToString())
                $str = $report | Out-String
                if($report.ContainsKey($key)){
                    $_ | Add-Member -MemberType NoteProperty -Name Creator -Value $report[$key].User
                }
                $_
            }
            
            return $snapshotsExtra
        }

        Function Send-SnapshotMail ($MailTo, $Snapshot) {
            $Subject = "Snapshot Reminder"

            $Body = @"
This is a reminder that you have a snapshot active for over $Retention days.

VM Name: $($Snapshot.VM)
Snapshot Name: $($Snapshot.Name)
Description: $($Snapshot.Description)
Created on: $($Snapshot.Created)
Created by: $($Snapshot.Creator)
"@

            Write-Debug "Attempting to email '$MailTo' about VM '$($Snapshot.VM)' snapshot '$($Snapshot.Name)', from '$MailFrom'."
            Write-Debug "Body of message:"
            Write-Debug "----------------"
            Write-Debug $Body
            Write-Debug "----------------"
            Send-MailMessage -To $MailTo -From $MailFrom -Subject $Subject -Body $Body -SmtpServer $SMTPRelay
        }


        # Main()
        if ($Credential) {
            Connect-VIServer $vSphereServer -Credential $Credential
        }

        $Snapshots = Get-VM | Get-Snapshot | Where {$_.Created -lt ((Get-Date).AddDays(-$Retention))}

        foreach ($Snap in $Snapshots) {
            $SnapshotInfo = Get-SnapshotExtra $Snap
            $MailTo = Find-OwnerEmail $SnapshotInfo.Creator
            Send-SnapshotMail $MailTo $SnapshotInfo
        }

        if (($Snapshots | Measure).Count -eq 0) {
            Write-Output "No snapshots older than $Retention days were found."
        }

        if ($Credential) {
            Disconnect-VIServer $vSphereServer -Confirm:$false
        }
    }
    End
    {
    }
}
