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
   Displays the statistics for both the cluster and per VMhost

   Courtesy of Vamshi Meda (@medavamshi) via http://tenthirtyam.org/per-cluster-cpu-and-memory-utilization-and-capacity-metrics-with-powercli/
.EXAMPLE
   Get-ClusterStats -Cluster Cluster1
.EXAMPLE
   Get-Cluster | Get-ClusterStats

   This will show output from all clusters returned from 'Get-Cluster'
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
        $Clustername = Get-Cluster $Cluster
        $Clusters = Get-View -ViewType ComputeResource | ? Name -Like $clustername.Name
        $Clusters | % {
            $Cluste     = $_
            $VMHostsView = $null
            $VMHostsView = Get-View $Cluste.Host -Property Name, Hardware, Config
            $VMss         = $Clustername | Get-VM
            $HostCount        = ($VMHostsView | Measure-Object).Count
            $VMCount          = 0 + ($VMss | Measure-Object).Count
            $VMsPerHost       = [math]::Round(($VMCount/$HostCount), 1)
            $vCPU             = 0 + ($VMss | Measure-Object -sum -Property NumCPU).Sum
            $allocatedram      = 0 + ($VMss | Measure-Object -sum -Property memorygb).Sum
            $avgrampervm      = [math]::Round(($allocatedram/$VMCount), 1)
            $pCPUSocket       = ($VMHostsView | % { $_.Hardware.CPUInfo.NumCpuPackages } | Measure-Object -Sum).Sum
            $TpCPUSocket     += $pCPUSocket
            $pCPUCore         = ($VMHostsView | % { $_.Hardware.CPUInfo.NumCpuCores } | Measure-Object -Sum).Sum
            $vCPUPerpCPUCore  = [math]::Round(($vCPU/$pCPUCore), 1)
            $onenode =[math]::Round((Get-Cluster $cluster | Get-VMHost | Select -First 1 | Measure-Object -Property memorytotalGB -Sum).Sum)
            $twonode =[math]::Round((Get-Cluster $cluster | Get-VMHost | Select -First 2 | measure-object -Property memorytotalGB -Sum).Sum)
            $onenodepcpucores =[math]::Round((Get-Cluster $cluster | Get-VMHost | Select -First 1 | Measure-Object -Property numcpu -Sum).Sum)
            $twonodepcpucores =[math]::Round((Get-Cluster $cluster | Get-VMHost | Select -First 2 | Measure-Object -Property numcpu -Sum).Sum)
            $totalclusterpcores_failover1= $pcpucore-$onenodepcpucores
            $totalclusterpcores_failover2= $pcpucore-$twonodepcpucores
            $TotalClusterRAMGB =[math]::Round((Get-cluster $cluster | get-vmhost | % { $_ } | Measure-Object -property memorytotalGB -Sum).Sum)
            $TotalClusterRAMFailoverOne = [math]::Round(($TotalClusterRAMGB-$onenode))
            $TotalClusterRAMFailvoerTwo = [math]::Round(($TotalClusterRAMGB-$twonode))
            $TotalClusterRAMusageGB =[math]::Round((Get-Cluster $cluster | Get-VMHost | % { $_ } | Measure-Object -Property memoryusageGB -Sum).Sum)
            $TotalClusterRAMUsagePercent = [math]::Round(($TotalClusterRAMusageGB/$TotalClusterRAMGB)*100)
            $TotalClusterRAMFreeGB = [math]::Round(($TotalClusterRAMGB-$TotalClusterRAMUsageGB))
            $TotalClusterRAMReservedGB = [math]::Round(($TotalClusterRAMGB/100)*15)
            $TotalClusterRAMAvailable = [math]::Round(($TotalClusterRAMFreeGB-$TotalClusterRAMReservedGB))
            $TotalClusterRAMAvailable_FailoverOne = [math]::Round(($TotalClusterRAMAvailable-$onenode))
            $TotalClusterRAMAvailable_failoverTwo = [math]::Round(($TotalClusterRAMAvailable-$twonode))
            $TotalClustervcpuperpcore_FailoverOne = [math]::Round(($vCPU/$totalclusterpcores_failover1))
            $TotalClustervcpuperpcore_failoverTwo = [math]::Round(($vCPU/$totalclusterpcores_failover2))
            $newvmcount = [math]::Round(($TotalClusterRAMAvailable/$avgrampervm))
            $newvmcount_failover1 = [math]::Round(($TotalClusterRAMAvailable_failoverone/$avgrampervm))
            $newvmcount_failover2 = [math]::Round(($TotalClusterRAMAvailable_failovertwo/$avgrampervm))
 
            New-Object PSObject |
            Add-Member -PassThru NoteProperty "ClusterName"          $clustername.Name    |
            Add-Member -PassThru NoteProperty "TotalClusterHostCount"          $HostCount    |
            Add-Member -PassThru NoteProperty "TotalClusterVMCount"          $VMCount    |
            Add-Member -PassThru NoteProperty "TotalClusterVM/Host"          $VMsPerHost    |
            Add-Member -PassThru NoteProperty "TotalClusterpCPUSocket"          $TpCPUSocket   |
            Add-Member -PassThru NoteProperty "TotalClusterpCPUCore"          $pCPUCore   |
            Add-Member -PassThru NoteProperty "TotalClustervCPUCount"          $VCPU    |
            Add-Member -PassThru NoteProperty "TotalClustervCPU/pCPUCore"          $vcpuperpcpucore  |
            Add-Member -PassThru NoteProperty "TotalClustervCPU/pCPUCore After 1 Failover"          $TotalClustervcpuperpcore_FailoverOne  |
            Add-Member -PassThru NoteProperty "TotalClustervCPU/pCPUCore After 2 Failvoer"          $TotalClustervcpuperpcore_Failovertwo  |
            Add-Member -PassThru NoteProperty "TotalClusterRAMGB"          $TotalClusterRAMGB    |
            Add-Member -PassThru NoteProperty "TotalClusterRAMGB_Failover1"          $TotalClusterRAMFailoverOne    |
            Add-Member -PassThru NoteProperty "TotalClusterRAMGB_failover2"          $TotalClusterRAMFailvoerTwo    |
            Add-Member -PassThru NoteProperty "TotalClusterRAMUSAGEPercent"          $TotalClusterRAMUsagePercent    |
            Add-Member -PassThru NoteProperty "TotalClusterRAMUsageGB"     $TotalClusterRAMusageGB    |
            Add-Member -PassThru NoteProperty "TotalClusterRAMFreeGB"      $TotalClusterRAMfreeGB    |
            Add-Member -PassThru NoteProperty "TotalClusterRAMReservedGB(15%)"          $TotalClusterRAMReservedGB    |
            Add-Member -PassThru NoteProperty "RAM Available for NEW VMs in GB"          $TotalClusterRAMAvailable    |
            Add-Member -PassThru NoteProperty "RAM Available for NEW VMs in GB After 1 failover"          $TotalClusterRAMAvailable_FailoverOne    |
            Add-Member -PassThru NoteProperty "RAM Available for NEW VMs in GB After 2 failover"          $TotalClusterRAMAvailable_FailoverTwo    |
            Add-Member -PassThru NoteProperty "Allocated RAM per VM on an average"                          $avgrampervm    |
            Add-Member -PassThru NoteProperty "NEW VM's that can be provisioned based on Average RAM per VM"                          $newvmcount    |
            Add-Member -PassThru NoteProperty "NEW VM's that can be provisioned based on Average RAM per VM After 1 failover"          $newvmcount_failover1    |
            Add-Member -PassThru NoteProperty "NEW VM's that can be provisioned basde on Average RAM per VM After 2 Failover"          $newvmcount_failover2   
        }
 
        Get-Cluster $Cluster | Get-VMHost | % {
            $vmhost =$_
            $VMHostView = $VMHost | Get-View
            $VMHostModel      = ($VMHostsView | % { $_.Hardware.SystemInfo } | Group-Object Model | Sort -Descending Count | Select -First 1).Name
            $VMs = $VMHost | Get-VM #| ? { $_.PowerState -eq "PoweredOn" }
            $TotalRAMGB       = [math]::Round($vmhost.MemoryTotalGB)
            $TotalRAMUsageGB       = [math]::Round($vmhost.MemoryUsageGB)
            $TotalRAMfreeGB       = [math]::Round($TotalRAMGB-$TotalRAMUsageGB)
            $PercRAMUsed     = [math]::Round(($TotalRAMUsageGB/$TotalRAMGB)*100)
            $TotalRAMReservedFree   = [math]::Round(($TotalRAMGB/100)*15)
            $TotalRAMAvailable   = [math]::Round(($TotalRAMfreegb-$totalramreservedfree))

            New-Object PSObject |
            Add-Member -pass NoteProperty "VMhost"          $vmhost.Name    |
            Add-Member -pass NoteProperty Model          $vmhostmodel    |
            Add-Member -pass NoteProperty Sockets $VMHostView.Hardware.cpuinfo.NumCPUPackages   |
            Add-Member -pass NoteProperty Cores   $VMHostView.Hardware.cpuinfo.NumCPUCores      |
            Add-Member -pass NoteProperty Threads $VMHostView.Hardware.cpuinfo.NumCPUThreads    |
            Add-Member -pass NoteProperty VMCount (($VMs | Measure-Object).Count)               |
            Add-Member -pass NoteProperty vCPU    (0 + ($VMs | Measure-Object -Sum NumCPU).Sum) |
            Add-Member -pass NoteProperty vCPUperCore ((0 + ($VMs | Measure-Object -Sum NumCPU).Sum)/$VMHostView.Hardware.cpuinfo.NumCPUCores) |
            Add-Member -pass NoteProperty "RAMGB"           $TotalRAMGB            |
            Add-Member -pass NoteProperty "RAMUsageGB"           $totalramusageGB            |
            Add-Member -pass NoteProperty "RAMFreeGB"           $totalramfreeGB            |
            Add-Member -pass NoteProperty "RAMUsage%"             $PercRAMused    |
            Add-Member -pass NoteProperty "RAMReservedGB(15%)"           $totalramreservedfree            |
            Add-Member -pass NoteProperty "RAM Available for NEW VMs in GB"           $totalramavailable
        } | Sort VMhost | ft -AutoSize * | Out-String -Width 1024
    }
    End
    {
    }
}