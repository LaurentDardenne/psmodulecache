
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
#todo supprimer l'usage de variable Env: ?
<#
https://docs.github.com/fr/actions/security-guides/using-secrets-in-github-actions

- name: utiliser step env
  env:
    username: ${{ secrets.TEST_USERNAME }}
    password: ${{ secrets.TEST_PASSWORD }}
  run: |

le nom du fichier doit être connu avant de charger le module ( car le module recherche les repositories existant) :
l'enregistrement des nouveaux repo se fait avant et on doit connaitre les infos

          $RepositoriesAuthenticationFileName='RepositoriesCredential.Datas.ps1xml'
          $Env:PSModuleCacheCredentialFileName=$RepositoriesAuthenticationFileName

---
#Credential doit être un objet donet valide, pas null, même si le mot de passe est vide : $credential=[PSCredential]::Empty
$credential = New-Object PSCredential('token',$(ConvertTo-SecureString 'ts8bA3cmWUdaG9b6' -AsPlainText -Force))
Register-PackageSource -Name 'privatepsmodulecache' -Location 'https://nuget.cloudsmith.io/actionpsmodulecache/privatepsmodulecache/v2/' -Trusted -Credential $credential -ProviderName NuGet
Register-PSRepository -Name 'privatepsmodulecache' -SourceLocation 'https://nuget.cloudsmith.io/actionpsmodulecache/privatepsmodulecache/v2/' -InstallationPolicy 'trusted' -Credential $credential


Pas de résultat mais pas d'erreur :
find-module -Name * -Repository 'actionpsmodulecache-privatepsmodulecache'

NOK ( les cred sont faux,pas de résultat mais pas d'erreur ) :
find-module -Name * -Repository 'actionpsmodulecache-privatepsmodulecache' -Credential $credFaux

OK :
find-module -Name * -Repository 'actionpsmodulecache-privatepsmodulecache' -Credential $credential

On doit connaitre le nom du repo afin de retrouver les cred

#1-pas de repo avec cred, pas de ( nouveau ) pb

#2-deux repos mais un seul avec des cred
 find-module -Name PnP.PowerShell -Repository 'privatepsmodulecache', 'psgallery' -Credential $credential
Ici PSGet n'utilise les informations d'identification que si l'un des référentiels en demande un. Sinon, le cmdlet ne prend pas en compte le paramètre -Credential.

#3-trois repos dont deux avec des cred IMPOSSIBLE
 find-module -Name PnP.PowerShell -Repository 'privatepsmodulecache', 'privategallery' -Credential $credential

collision interroger + repo pour un même module (revoir les tests existant)

-->
Le texte de solution proposé sur github ne fonctionne qu'avec un seul Repo.
Save-module ne prend qu'un seul credential de repo mais on le connait

Find-module ne prend qu'un seul credential de repo et on interroge + repo on ne peut pas ( à tester) indiquer un seul cred pour + repo.
La v2 de psget associe en dehors du module un nom de repo à un cred.
On doit utiliser un nom de repo pour utiliser des credentials !!! Syntaxe RQMN.

dans la fonction 'Find-ModuleCacheDependencies' on doit déterminer comment rechercher le module dans un seul ou dans plusieurs repo

psrepository ne permet pas de savoir si un repo nécessite des credential :
Invoke-RESTmethod -uri 'https://nuget.cloudsmith.io/actionpsmodulecache/privatepsmodulecache/v2'
-> ok ou error ( a analyser)
 $e.Exception : System.Net.WebException
  $e.Exception.Response.StatusCode

System.Net.HttpStatusCode: Unauthorized (401) indicates that the requested resource requires authentication.
ici pas de besoin de connaitre la path de nuget.exe

créer la hashtable, valide l'uri et les cred, ajoute un champ bool 'RepodNeedCredential'.
La hashtable doit contenir tout les noms de repo déclaré.
le fichier existe avant le chargement du module on peut donc connaitre les repo sans crédential ?
par défaut on peut pas savoir lesquel utilise des cred
<--

PSget v3
  CredentialInfo = [Microsoft.PowerShell.PSResourceGet.UtilClasses.PSCredentialInfo]
  on couple psget avec un vault, on enregistre le nom du vault et la clé et c'est le vault qui donne le credential

doc insuffisante on couple deux module mais la doc n'explique pas comment compléter le scénario de l'exemple 4 :
 https://learn.microsoft.com/fr-fr/powershell/module/microsoft.powershell.psresourceget/register-psresourcerepository?view=powershellget-3.x

 todo Tester l'exemple 4 avec privatepsmodulecache
 https://learn.microsoft.com/fr-fr/powershell/module/microsoft.powershell.psresourceget/register-psresourcerepository?view=powershellget-3.x

 todo rechercher dans la doc de PsSecretManagement


 fichier des repo ; psget le lit une fois lors du charglment du moudle, il est utilisé par les deux sessions( 5.1 et PSCore)
 mais n'est pas mis à jour en cas de modif dans l'une des deux sesionss
#>
$RepositoriesAuthenticationFileName = 'RepositoriesCredential.Datas.ps1xml'
$Env:PSModuleCacheCredentialFileName = $RepositoriesAuthenticationFileName


#TODO à l'extérieur du script ?
if ((Test-Path env:CloudsmithAccountName, env:CloudsmithPassword) -contains $false)
{ Throw "The environment variables 'CloudsmithAccountName' and 'CloudsmithPassword' must exist." }

$RepositoriesCredential = @{}
$Credential = New-Object PSCredential($env:CloudsmithAccountName, $(ConvertTo-SecureString $env:CloudsmithPassword -AsPlainText -Force) )
$RepositoriesCredential.$CloudsmithPrivateRepositoryName = $Credential

#TODO nécessaire ?
#!!! le traitement doit être commun au WF, à placer dans le module ??
<#
l'appelant connait le nom du repo(clé) et le credential(valeur)
le module connait le traitement ( create hashtable) et le nom du fichier
#>

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

#todo usage séquentiel.Le fichier xml des repo est partagé par PS v5.1 et PS Core
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
