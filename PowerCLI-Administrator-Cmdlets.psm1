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
 
            New-Object PSObject |
            Add-Member -PassThru NoteProperty "Cluster Name"                                       $ClusterName.Name             |
            Add-Member -PassThru NoteProperty "Number of Hosts"                                    $HostCount                    |
            Add-Member -PassThru NoteProperty "Number of VMs"                                      $VMCount                      |
            Add-Member -PassThru NoteProperty "VMs Per Host"                                       $VMsPerHost                   |
            Add-Member -PassThru NoteProperty "pCPUs (Socket)"                                     $pCPUSocket                   |
            Add-Member -PassThru NoteProperty "pCPU (Core)"                                        $pCPUCore                     |
            Add-Member -PassThru NoteProperty "vCPU Count"                                         $vCPU                         |
            Add-Member -PassThru NoteProperty "vCPU/pCPU Core"                                     $vCPUperpCPUCore              |
            Add-Member -PassThru NoteProperty "vCPU/pCPU Core (1 node failure)"                    $vCPUperpCore_OneNodeFailover |
            Add-Member -PassThru NoteProperty "vCPU/pCPU Core (2 node failure)"                    $vCPUperpCore_TwoNodeFailover |
            Add-Member -PassThru NoteProperty "RAM (GB)"                                           $RAMGB                        |
            Add-Member -PassThru NoteProperty "RAM (1 node failure)"                               $RAM_OneNodeFailover          |
            Add-Member -PassThru NoteProperty "RAM (2 node failure)"                               $RAM_TwoNodeFailover          |
            Add-Member -PassThru NoteProperty "RAM Usage (%)"                                      $RAMUsagePercent              |
            Add-Member -PassThru NoteProperty "RAM Usage (GB)"                                     $RAMUsageGB                   |
            Add-Member -PassThru NoteProperty "RAM Free (GB)"                                      $RAMFreeGB                    |
            Add-Member -PassThru NoteProperty "RAM Reserved (GB, 15%)"                             $RAMReservedGB                |
            Add-Member -PassThru NoteProperty "RAM Available for NEW VMs (GB)"                     $RAMAvailable                 |
            Add-Member -PassThru NoteProperty "RAM Available for NEW VMs (1 node failure)"         $RAMAvailable_OneNodeFailover |
            Add-Member -PassThru NoteProperty "RAM Available for NEW VMs (2 node failure)"         $RAMAvailable_TwoNodeFailover |
            Add-Member -PassThru NoteProperty "Average Allocated RAM/VM"                           $AvgRAMPerVM                  |
            Add-Member -PassThru NoteProperty "Est. # of new VMs based on RAM/VM"                  $NewVMs                       |
            Add-Member -PassThru NoteProperty "Est. # of new VMs based on RAM/VM (1 node failure)" $NewVMs_OneNodeFailover       |
            Add-Member -PassThru NoteProperty "Est. # of new VMs based on RAM/VM (2 node failure)" $NewVMs_TwoNodeFailover   
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

            New-Object PSObject |
            Add-Member -PassThru NoteProperty "VMhost"                   $VMHost.Name                                |
            Add-Member -PassThru NoteProperty "Model"                    $VMHostModel                                |
            Add-Member -PassThru NoteProperty "Sockets"                  $VMHostView.Hardware.cpuinfo.NumCPUPackages |
            Add-Member -PassThru NoteProperty "Cores"                    $VMHostView.Hardware.cpuinfo.NumCPUCores    |
            Add-Member -PassThru NoteProperty "Threads"                  $VMHostView.Hardware.cpuinfo.NumCPUThreads  |
            Add-Member -PassThru NoteProperty "VMs"                      $VMCount                                    |
            Add-Member -PassThru NoteProperty "vCPU"                     $CPUCount                                   |
            Add-Member -PassThru NoteProperty "vCPU/Core"                $vCPUPerCore                                |
            Add-Member -PassThru NoteProperty "RAM (GB)"                 $RAMGB                                      |
            Add-Member -PassThru NoteProperty "RAM Usage (GB)"           $RAMUsageGB                                 |
            Add-Member -PassThru NoteProperty "RAM Free (GB)"            $RAMFreeGB                                  |
            Add-Member -PassThru NoteProperty "RAM Usage (%)"            $PercentRAMused                             |
            Add-Member -PassThru NoteProperty "15% RAM Reservation (GB)" $RAMreservedFree                            |
            Add-Member -PassThru NoteProperty "Available RAM (GB)"       $RAMavailable
        } | Sort VMhost | ft -AutoSize * | Out-String -Width 1024
    }
    End
    {
    }
}