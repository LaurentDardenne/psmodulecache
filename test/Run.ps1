#We only test the behavior of the code in a Powershell session.
#We do not test the functioning of the action into a workflow.

Param()

$ErrorActionPreference = 'stop'
try {
    #The tests depend on the version of the Runner its image is regularly updated.
    if (-not (Test-Path env:CI) ) {
        $env:RUNNER_OS = 'Windows'
        $env:GITHUB_WORKFLOW = 'WorkflowDemo'
        If ( (Test-Path Variable:isWindows) -eq $false) {
            #Powershell v5.1 only for Windows OS
            $global:isWindows = $true
            $global:IsLinux = $global:IsCoreCLR = $global:IsMacOS = $false
            #note: under WSL $IsLinux=False and the Windows File System is by default case insensitive.
        }
    }

    #todo .\MatrixRepositoriesWithCredential.yml on doit configurer les deux versions ?
    #todo Tester si la création d'un PSrepo sous v5.1 est accessible sous PSCore ( doit-on recharger le module s'il est en mémoire au monet de la création ?)
    # Get-PackageProvider; Get-PackageSource; Get-PSRepository

    #v2
    # C:\Users\Laurent\AppData\Local\PowerShellGet\PSResourceRepository.xml
    # C:\Users\Laurent\AppData\Local\PowerShellGet\PSResourceRepository.xml
    #C:\Users\Laurent\AppData\Local\Microsoft\Windows\PowerShell\PowerShellGet\PSRepositories.xml

    #v3
    #C:\Users\Laurent\AppData\Local\PSResourceGet\PSResourceRepository.xml






    . "$PSScriptRoot\Dependencies\Register-TestRepository.ps1"

    #Name conflict tests require modules named 'Main' and 'string' to exist in PSGallery.
    Find-Module -Name Main -Repository PSGallery > $null
    Find-Module -Name string -Repository PSGallery > $null

    $Configuration = New-PesterConfiguration

    $Configuration.filter.Tag = 'HashtableValidation' # @('shell', 'keygen', 'ModulePath', 'PrefixIdentifier', 'PowershellGetVersion', 'CaseInsensitive', 'Dependencies', 'BasicFeatures', 'ModuleNameDuplication', 'DuplicateSavePath', 'NamingWithUbuntu')

    $Configuration.Output.Verbosity = 'Detailed'
    $Configuration.Output.StackTraceVerbosity = 'Full'
    $Configuration.TestResult.Enabled = $true
    $Configuration.TestResult.OutputPath = "$Env:temp\testResults.xml"
    $Configuration.Run.PassThru = $true

    $BaseDirectory = Resolve-Path "$PSScriptRoot\.."
    Import-LocalizedData -BindingVariable global:PSModuleCacheResources -FileName PSModuleCache.Resources.psd1 -ErrorAction Stop -BaseDirectory $BaseDirectory

    #The response time of a call to Find-Module on PSGallery can be degraded (between 30 and 60 seconds), where Myget responds between 3 and 6 seconds.
    $testResult = Invoke-Pester -Configuration $Configuration

    if ($testResult.FailedCount -ne 0)
    { throw 'One or more Pester tests failed, cannot continue.' }

    $Configuration = New-PesterConfiguration
    $Configuration.filter.Tag = 'SaveModuleCache'
    $Configuration.Output.Verbosity = 'Detailed'
    $Configuration.Output.StackTraceVerbosity = 'Full'
    $Configuration.TestResult.Enabled = $true
    $Configuration.TestResult.OutputPath = "$Env:temp\testResults2.xml"
    $Configuration.Run.PassThru = $true

    $testResult = Invoke-Pester -Configuration $Configuration
    if ($testResult.FailedCount -ne 0)
    { throw 'One or more Pester tests failed, cannot continue.' }

} catch {
    Write-Warning "Exit code`r`n$_"
    throw $_
}