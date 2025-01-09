#HashtableOfCredential.Tests.ps1
# Check if a serialized object matches the expected structure

#todo tjr tester la structure, mais les test d'un PsRepo avec cred dépend de la config du reposoitry Github...
<#
!!! combinaisons pour les tests
un repo : psgallery (FAIT)
deux repos : psgallery et psmodulecache (FAIT)

un repo sans et un avec credential: psgallery,privatepsmodulecache (A FAIRE)
deux avec credential: privatepsmodulecache et privateDuplicatepsmodulecache (A FAIRE)

duplication avec deux repos : psgallery et psmodulecache
duplication avec deux repos, un sans et un autre avec credential :  psgallery et privateDuplicatepsmodulecache (A FAIRE)
duplication avec deux repos, les deux credential :  psgallery et privateDuplicatepsmodulecache (A FAIRE)


Créer les modules à publier dans un repo avec credential ( pas de duplication).
Créer un repository pour les module dupliqués ( avec lequel/lesquels ?)
#>
$global:PSModuleCacheResources = Import-PowerShellDataFile "$PSScriptRoot/../PSModuleCache.Resources.psd1" -EA Stop
Import-Module "$PSScriptRoot/../PSModuleCache.psd1" -Force

Describe "'Test-RepositoriesCredential' function. When there is no error." -Tag 'HashtableValidation' {

   Context "Valid hashtable object" {
      It "Only one entry" -Skip:((Test-Path Env:CLOUDSMITHPASSWORD) -eq $false) {
         #todo utiliser un fichier
         $Credential = New-Object PSCredential($Env:CLOUDSMITHACCOUNTNAME, $(ConvertTo-SecureString $Env:CLOUDSMITHPASSWORD -AsPlainText -Force) )
         $RepositoriesCredential = @{}
         $RepositoriesCredential.'PSGallery' = $Credential

         InModuleScope 'PsModuleCache' -Parameters @{ Datas = $RepositoriesCredential } {
            $script:FunctionnalErrors.Clear()
            Test-RepositoriesCredential -InputObject $Datas | Should -Be $true
         }
      }

      It "Two entries" -Skip:((Test-Path Env:CLOUDSMITHPASSWORD) -eq $false) {
         #todo utiliser un fichier
         $RepositoriesCredential = @{}
         $RepositoriesCredential.'PSGallery' = [PSCredential]::Empty
         $RepositoriesCredential.'OttoMatt' = [PSCredential]::Empty

         InModuleScope 'PsModuleCache' -Parameters @{ Datas = $RepositoriesCredential } {
            $script:FunctionnalErrors.Clear()
            Test-RepositoriesCredential -InputObject $Datas | Should -Be $true
         }
      }

      It "Find-Module with credential" -Skip:((Test-Path Env:CI) -eq $false) {
         #todo créer un fichier de test
         $Path = Join-Path $home -ChildPath $Env:PSModuleCacheCredentialFileName
         $RepositoriesCredential = Import-Clixml -Path $Path

         $Credential = $RepositoriesCredential.$Env:CloudsmithRepositoryName
         Find-Module -Name Etsdatetime -Repository $Env:CloudsmithRepositoryName -AllowPrerelease -Credential $credential | Should -Not -Be $Null
      }
      #todo tester toute la chaine cf.savemodulecache ou CheckBasicBehaviors ?
   }
}

Describe "Repositories with credential. When there error." -Tag 'HashtableValidation' {
   Context "Invalid file." {
      It 'The file exist but contains zero octet.' {
         InModuleScope 'PsModuleCache' -Parameters @{ Datas = $RepositoriesCredential } {
            $script:FunctionnalErrors.Clear()
            #todo home pointe sur New-Item  "TestDrive:\file1.txt" ?
            [string]::Empty > "$script:RepositoriesAuthenticationFullPath"

            Import-Credential -Path $script:RepositoriesAuthenticationFullPath > $null

            $script:FunctionnalErrors.Count | Should -Be 1
            $script:FunctionnalErrors[0] | Should -Match '^Impossible to read the credentials XML file'
         }
      }

      It 'The file exist but it is not a xml file.' {
         InModuleScope 'PsModuleCache' -Parameters @{ Datas = $RepositoriesCredential } {
            $script:FunctionnalErrors.Clear()
            @'
Objs Version="1.1.0.1" xmlns="http://schemas.microsoft.com/powershell/2004/04"
'@ > "$script:RepositoriesAuthenticationFullPath"

            Import-Credential -Path $script:RepositoriesAuthenticationFullPath > $null

            $script:FunctionnalErrors.Count | Should -Be 1
            $script:FunctionnalErrors[0] | Should -Match '^Impossible to read the credentials XML file'
         }
      }

      It 'The file exist and it contains a valid xml but Import-ClimXml return $null.' {
         InModuleScope 'PsModuleCache' -Parameters @{ Datas = $RepositoriesCredential } {
            $script:FunctionnalErrors.Clear()
            @'
<Objs Version="1.1.0.1" xmlns="http://schemas.microsoft.com/powershell/2004/04">
</Objs>
'@ > "$script:RepositoriesAuthenticationFullPath"

            Import-Credential -Path $script:RepositoriesAuthenticationFullPath > $null

            $script:FunctionnalErrors.Count | Should -Be 1
            $script:FunctionnalErrors[0] | Should -Be $global:PSModuleCacheResources.InvalidObject
         }
      }

      Context "Invalid setting." {
         It "Action`'s 'UseRepositoriesWithCredential' parameter contains true but the credential file do not exist." {
            throw 'a faire' #todo tester la présence et l'absence de fichier de credentials
         }

         It "Action`'s 'UseRepositoriesWithCredential' parameter contains false but the file exist." {
            throw 'a faire'
         }
      }

      Context "'Test-RepositoriesCredential' function. Invalid credential hashtable." {
         It "Invalid serialized object : ValidationMustBeHashtable" {
            $RepositoriesCredential = @(1..2)

            InModuleScope 'PsModuleCache' -Parameters @{ Datas = $RepositoriesCredential } {
               $script:FunctionnalErrors.Clear()
               Test-RepositoriesCredential -InputObject $Datas | Should -Be $false
               $script:FunctionnalErrors.Count | Should -Be 1
               $script:FunctionnalErrors[0] | Should -Be $global:PSModuleCacheResources.ValidationMustBeHashtable
            }
         }

         It "Invalid serialized object : ValidationMustContainAtLeastOneEntry" {
            $RepositoriesCredential = @{}

            InModuleScope 'PsModuleCache' -Parameters @{ Datas = $RepositoriesCredential } {
               $script:FunctionnalErrors.Clear()
               Test-RepositoriesCredential -InputObject $Datas | Should -Be $false
               $script:FunctionnalErrors.Count | Should -Be 1
               $script:FunctionnalErrors[0] | Should -Be $global:PSModuleCacheResources.ValidationMustContainAtLeastOneEntry
            }
         }

         It "Invalid serialized object : ValidationWrongItemType" {
            $Credential = New-Object PSCredential('Test', $(ConvertTo-SecureString 'Test' -AsPlainText -Force) )
            $RepositoriesCredential = @{}
            $RepositoriesCredential.'PSGallery' = $Credential
            $RepositoriesCredential.'MyGet' = @(1..2)

            InModuleScope 'PsModuleCache' -Parameters @{ Datas = $RepositoriesCredential } {
               $script:FunctionnalErrors.Clear()
               Test-RepositoriesCredential -InputObject $Datas | Should -Be $false
               $script:FunctionnalErrors.Count | Should -Be 1
               $script:FunctionnalErrors[0] | Should -Be $global:PSModuleCacheResources.ValidationWrongItemType
            }
         }

         It "Invalid serialized object : ValidationInvalidKey" {
            $Credential = New-Object PSCredential('Test', $(ConvertTo-SecureString 'Test' -AsPlainText -Force) )
            $RepositoriesCredential = @{}
            $RepositoriesCredential.'' = $Credential

            InModuleScope 'PsModuleCache' -Parameters @{ Datas = $RepositoriesCredential } {
               $script:FunctionnalErrors.Clear()
               Test-RepositoriesCredential -InputObject $Datas | Should -Be $false
               $script:FunctionnalErrors.Count | Should -Be 1
               $script:FunctionnalErrors[0] | Should -Be $global:PSModuleCacheResources.ValidationInvalidKey
            }
         }

         It "Invalid serialized object : ValidationUnknownRepository" {
            $Credential = New-Object PSCredential('Test', $(ConvertTo-SecureString 'Test' -AsPlainText -Force) )
            $RepositoriesCredential = @{}
            $RepositoriesCredential.'PSGallery' = $Credential
            $RepositoriesCredential.'UnknownRepository' = $Credential

            InModuleScope 'PsModuleCache' -Parameters @{ Datas = $RepositoriesCredential } {
               $script:FunctionnalErrors.Clear()
               Test-RepositoriesCredential -InputObject $Datas | Should -Be $false
               $script:FunctionnalErrors.Count | Should -Be 1
               $script:FunctionnalErrors[0] | Should -Be $global:PSModuleCacheResources.ValidationUnknownRepository
            }
         }
      }
   }
