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