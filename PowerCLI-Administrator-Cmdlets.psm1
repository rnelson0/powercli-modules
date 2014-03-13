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