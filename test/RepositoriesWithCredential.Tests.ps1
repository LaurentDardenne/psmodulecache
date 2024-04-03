#RepositoriesWithCredential.Tests.ps1
# Check if a serialized object matches the expected structure

<# TODO
!!! combinaisons pour les tests
un repo : psgallery (FAIT)
deux repos : psgallery et psmodulecache (FAIT)

un repo sans et un avec credential: psgallery,privatepsmodulecache (A FAIRE)
deux avec credential: privatepsmodulecache et privateDuplicatepsmodulecache (A FAIRE)

duplication avec deux repos : psgallery et psmodulecache
duplication avec deux repos, un sans et un autre avec credential :  psgallery et privateDuplicatepsmodulecache (A FAIRE)
duplication avec deux repos, les deux credential :  psgallery et privateDuplicatepsmodulecache (A FAIRE)


Créer les module à publier dans un repo avec credential ( pas de duplication).
Créer une repository pour les module dupliqués ( avec lequel/lesquels ?)
#>
$global:PSModuleCacheResources = Import-PowerShellDataFile "$PSScriptRoot/../PSModuleCache.Resources.psd1" -EA Stop
Import-Module "$PSScriptRoot/../PSModuleCache.psd1" -Force

Describe 'Test-RepositoriesCredential function. When there is no error.' -Tag 'HashtableValidation' {

   Context "Valid hashtable object" {
      It "Only one entry" -Skip:((Test-Path Env:CLOUDSMITHPASSWORD) -eq $false) {
         $Credential = New-Object PSCredential($Env:CLOUDSMITHACCOUNTNAME, $(ConvertTo-SecureString $Env:CLOUDSMITHPASSWORD -AsPlainText -Force) )
         $RepositoriesCredential = @{}
         $RepositoriesCredential.'PSGallery' = $Credential

         InModuleScope 'PsModuleCache' -Parameters @{ Datas = $RepositoriesCredential } {
            $script:FunctionnalErrors.Clear()
            Test-RepositoriesCredential -InputObject $Datas | Should -Be $true
         }
      }

      It "Two entries" -Skip:((Test-Path Env:CLOUDSMITHPASSWORD) -eq $false) {
         $Credential = New-Object PSCredential($Env:CLOUDSMITHACCOUNTNAME, $(ConvertTo-SecureString $Env:CLOUDSMITHPASSWORD -AsPlainText -Force) )
         $RepositoriesCredential = @{}
         $RepositoriesCredential.'PSGallery' = $Credential
         $RepositoriesCredential.'OttoMatt' = $Credential

         InModuleScope 'PsModuleCache' -Parameters @{ Datas = $RepositoriesCredential } {
            $script:FunctionnalErrors.Clear()
            Test-RepositoriesCredential -InputObject $Datas | Should -Be $true
         }
      }

      It "Find-Module with credential" -Skip:((Test-Path Env:CI) -eq $false) {
         $Path = Join-Path $home -ChildPath $Env:PSModuleCacheCredentialFileName
         $RepositoriesCredential = Import-Clixml -Path $Path

         $Credential = $RepositoriesCredential.$Env:CloudsmithRepositoryName
         Find-Module -Name Etsdatetime -Repository $Env:CloudsmithRepositoryName -AllowPrerelease -Credential $credential | Should -Not -Be $Null
      }
      #todo tester toute la chaine cf.savemodulecache ou CheckBasicBehaviors ?
   }
}

Describe 'Test-RepositoriesCredential function. When there error.' -Tag 'HashtableValidation' {

   Context "Invalid credential hashtable." {
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
