
Function New-ModulePublication {
    param(
        [Parameter(Mandatory = $True, position = 0)]
        $Name,

        [Parameter(position = 1)]
        $RequiredVersion,

        $Repository = 'PSModuleCache',

        [Switch]$AllowPrerelease
    )

    @{
        Name            = $Name;
        Repository      = $Repository;
        RequiredVersion = $RequiredVersion;
        AllowPrerelease = $AllowPrerelease.isPresent;
    }
}
Function Test-PsRepository {
    param ([String] $RepositoryName)
    try {
        Get-PSRepository -Name $RepositoryName -EA Stop > $null
        $True
    } catch {
        $False
    }
}

$CloudsmithRepositoryName = 'psmodulecache'
$CloudsmithUriLocation = 'https://nuget.cloudsmith.io/psmodulecache/test/v2/'

$CloudsmithPrivateRepositoryName = 'privatepsmodulecache'
#todo change URI
#todo download all packages from psmodulecache ?
$CloudsmithPrivateUriLocation = 'https://nuget.cloudsmith.io/actionpsmodulecache/privatepsmodulecache/v2/'

#todo dans un step (externe) ou dans les script (interne) ?
$RepositoriesAuthenticationFileName = 'RepositoriesCredential.Datas.ps1xml'
$Env:PSModuleCacheCredentialFileName = $RepositoriesAuthenticationFileName


#TODO à l'extérieur du script ?
if ((Test-Path env:CloudsmithAccountName, env:CloudsmithPassword) -contains $false)
{ Throw "The environment variables 'CloudsmithAccountName' and 'CloudsmithPassword' must exist." }

$RepositoriesCredential = @{}
$Credential = New-Object PSCredential($env:CloudsmithAccountName, $(ConvertTo-SecureString $env:CloudsmithPassword -AsPlainText -Force) )
$RepositoriesCredential.$CloudsmithPrivateRepositoryName = $Credential

#TODO nécessaire ?

#Save credential datas into the filesystem
#$RepositoriesCredential | Export-Clixml -Path (Join-Path $home -ChildPath $RepositoriesAuthenticationFileName)

$RemoteRepositories = @(
    [PsCustomObject]@{
        name            = 'OttoMatt'
        publishlocation = 'https://www.myget.org/F/ottomatt/api/v2/package'
        sourcelocation  = 'https://www.myget.org/F/ottomatt/api/v2'
        credential      = $null
    },

    [PsCustomObject]@{
        name            = $CloudsmithPrivateRepositoryName
        publishlocation = $CloudsmithPrivateUriLocation
        sourcelocation  = $CloudsmithPrivateUriLocation
        credential      = $null
    },


    [PsCustomObject]@{
        name            = $CloudsmithRepositoryName
        publishlocation = $CloudsmithUriLocation
        sourcelocation  = $CloudsmithUriLocation
        credential      = $Credential
    }
)

Try {
    Get-PackageSource PSModuleCache -ErrorAction Stop >$null
} catch {
    if ($_.CategoryInfo.Category -ne 'ObjectNotFound') {
        throw $_
    } else {
        Register-PackageSource -Name $CloudsmithRepositoryName -Location $CloudsmithUriLocation -ProviderName NuGet -Trusted > $null
    }
}

Try {
    Get-PackageSource PrivatePSModuleCache -ErrorAction Stop >$null
} catch {
    if ($_.CategoryInfo.Category -ne 'ObjectNotFound') {
        throw $_
    } else {
        Register-PackageSource -Name $CloudsmithPrivateRepositoryName -Location $CloudsmithPrivateUriLocation  -Credential $credential -ProviderName NuGet -Trusted  > $null
    }
}

foreach ($Repository in $RemoteRepositories) {
    $Name = $Repository.Name
    try {
        Get-PSRepository $Name -ErrorAction Stop >$null
    } catch {
        if ($_.CategoryInfo.Category -ne 'ObjectNotFound') {
            throw $_
        } else {
            $Parameters = @{
                Name               = $Name
                SourceLocation     = $Repository.SourceLocation
                PublishLocation    = $Repository.PublishLocation
                InstallationPolicy = 'Trusted'
            }
            Write-Verbose "Register repository '$($Repository.Name). With credential ?$($null -ne $Repository.Credential)"

            if ($null -ne $Repository.Credential )
            { $Parameters.Add('Credential', $Credential) }

            # An invalid Web Uri is managed by Register-PSRepository
            Register-PSRepository @Parameters  > $null
        }
    }
}
