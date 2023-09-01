@{
    PSDependOptions = @{
        DependencyType = 'PSGalleryModule'
        SkipPublisherCheck = $true
        Force = $true
        AllowClobber = $true
    }
    
    InvokeBuild      = 'latest'
    PSScriptAnalyzer = 'latest'
    Pester           = 'latest'
}
