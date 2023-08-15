[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [string]
    $Task,

    [Parameter(Mandatory = $true)]
    [string]
    $Version,

    [Parameter()]
    [switch]
    $Preview
)


task Build.Module {

}

task Tests.Unit {

}

task Test.Meta {

}

task Test.All Test.Meta, Test.Unit {

}

task Publish.Module {
    
}
