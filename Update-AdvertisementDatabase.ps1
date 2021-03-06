<#
.SYNOPSIS
Script for software "Windows PowerShell" (TM) developed by "Microsoft Corporation".

.DESCRIPTION
* Author: David Kriz (from Brno in Czech Republic; GPS: 49.1912789N, 16.6123581E).
* OS    : "Microsoft Windows" version 7 [6.1.7601]
* License: GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
            ktera je dostupna na adrese "https://www.gnu.org/licenses/gpl.html" .

.PARAMETER DebugLevel
Turn ON debug mode of this script.
It is useful only when you are Developer or Tester of this script.

.PARAMETER LogFile
Full name of text-file where will be added log/status messages from this script.

.PARAMETER NoOutput2Screen
Disable any output to your screen/display/monitor. 
It is useful when you run this script automatically as background process (For example by "Windows Task Scheduler").

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
None (Except of some text messages on your screen).

.COMPONENT
Module "DavidKriz" ($env:USERPROFILE\Documents\WindowsPowerShell\Modules\DavidKriz\DavidKriz.psm1)

.EXAMPLE
C:\PS> & "$($env:USERPROFILE)\_PUB\HOUSING\New\Update-AdvertisementDatabase.ps1" -OutputDataOnly -PauseMax 0 -ImportToOdsFile
C:\PS> & "$($env:USERPROFILE)\_PUB\HOUSING\New\Update-AdvertisementDatabase.ps1" -ImportToOdsFile

.LINK
Author : mailto: dakr <at> email <dot> cz, http://cz.linkedin.com/in/davidkriz/

.LINK
    Parsing HTML Webpages with Powershell : http://woshub.com/parsing-html-webpages-with-powershell/

.NOTES
    After finish you can import output CSV-file to "Microsoft Office Excel" or "LibreOffice Cals".
    To "LibreOffice Cals" you can make it easier by sw "C:\Program Files\PoBin\Csv2Odf" (http://csv2odf.sourceforge.net):
    
#>

param(
     [string]$InputFile = ''
    ,[string[]]$URLs = @()
    ,[Byte]$PauseMin = 16
    ,[Byte]$PauseMax = 55
    ,[switch]$OutputDataOnly
    ,[string]$City = 'Brno'
    ,[switch]$ImportToOdsFile
    ,[string]$ImportToOdsFileTemplate = (($env:USERPROFILE)+'\_PUB\HOUSING\New\Update-AdvertisementDatabase_-_Template_for_Csv2Odf.ods')
    ,[string]$ImportToOdsFileLibreOffice = ''
    ,[switch]$NoOutput2Screen
    ,[switch]$help
    ,[switch]$NoSound
    ,[string]$ConfigFile = ''
    ,[string]$LogFile = ''
    ,[string]$OutputFile = ''
    ,[string]$RunFromSW = ''   # Windows_Task_Scheduler
    ,[byte]$DebugLevel = 0
    ,[switch]$Verbose
    ,[uint16]$PSWindowWidth = 0
    #  [string]$File = $(throw 'As 1.parameter to this script you have to enter name of input file ...')
)

#region TemplateBegin
#region AboveVARIABLES
[System.UInt16]$ThisAppVersion = 21

<# 
    * about_Functions_Advanced_Parameters : http://technet.microsoft.com/en-us/library/dd347600.aspx
    * How to include library of common functions (dot-sourcing) : http://technet.microsoft.com/en-us/library/ee176949.aspx
        . "C:\Program Files\David_KRIZ\DavidKrizLibrary.ps1"
    * about_Preference_Variables : https://technet.microsoft.com/en-us/library/hh847796.aspx
#>

if ($DebugLevel -gt 0) {
    $global:DebugPreference = [System.Management.Automation.ActionPreference]::Continue
	if (-not ((Get-Host).Name -ilike 'Windows PowerShell ISE *')) {
        [boolean]$global:TranscriptStarted = $True
        Start-Transcript -Path C:\Temp\PowerShell-Transcript.log -Append -Force
    }
} else {
    [boolean]$global:TranscriptStarted = $False
}
Set-PSDebug -Strict
if ($Verbose.IsPresent) { $global:VerbosePreference = [System.Management.Automation.ActionPreference]::Continue }



# *** CONSTANTS:
[string]$AdminComputer="$env:COMPUTERNAME"
[string]$AdminUser='dkriz'
[string]$DevelopersComputer = 'N60045'
$FormatTableProperties = @{Label='WWW Source'; Expression={$_.WWWSource}}, `
    @{Label='ID'; Expression={$_.ID}}, @{Label='Street'; Expression={$_.Street}}, `
    @{Label='District'; Expression={$_.District}}, @{Label='Price'; Expression={$_.Price}}, `
    @{Label='S#'; Expression={$_.Size}}, @{Label='+'; Expression={$_.SizePlus}}, `
    @{Label='m2'; Expression={$_.Sizem2}}, @{Label='Building'; Expression={$_.BuildingType}}

New-Variable -Option Constant -Name OurCompanyName -Value 'RWE' -ErrorAction SilentlyContinue
[string]$NewLine = ([char]13)+([char]10)
[int]$PSWindowWidthI = 0
[string]$TextIsNumberRegEx = '^\s*[\d\.\,]+\s*$'
[string]$ThisAppName = Split-Path $PSCommandPath -leaf
$ThisApp = @{}
$ThisApp.Name       = $MyInvocation.MyCommand.Name
$ThisApp.Definition = $MyInvocation.MyCommand.Definition
$ThisApp.Directory  = (Split-Path (Resolve-Path $MyInvocation.MyCommand.Definition) -Parent)
$ThisApp.StartDir   = (Get-Location -PSProvider FileSystem).ProviderPath
$ThisApp.WinOS      = (Get-WmiObject Win32_OperatingSystem)
$ThisApp.WinVer     = [int]$ThisApp.WinOS.Version.Split(".")[0]
$ThisApp.HostVer    = [int](Get-Host).Version.Major
[Boolean]$Write2EventLogEnabled = $false

Try { $PSWindowWidthI = ((Get-Host).UI.RawUI.WindowSize.Width) - 1 } Catch { $PSWindowWidthI = 0 }
Get-Variable -Name PSWindowWidth -Scope Script -ErrorAction SilentlyContinue | Out-Null
If ($?) { if ($PSWindowWidth -gt 0) { $PSWindowWidthI = $PSWindowWidth } }
if (($PSWindowWidthI -lt 1) -or ($PSWindowWidthI -gt 1000) -or ($PSWindowWidthI -eq $null)) { 
    $PSWindowWidthI = ((Get-Host).UI.RawUI.BufferSize.Width) - 1
    if (($PSWindowWidthI -lt 1) -or ($PSWindowWidthI -gt 1000) -or ($PSWindowWidthI -eq $null)) { $PSWindowWidthI = 80 }
}
#endregion AboveVARIABLES


<# 
    *** Declaration of VARIABLES: _____________________________________________
    													* http://msdn.microsoft.com/en-us/library/ya5y69ds.aspx
    													* about_Scopes : http://technet.microsoft.com/en-us/library/hh847849.aspx
                                                        * [string[]]$Pole1D = @()
                                                        * New-Object -TypeName System.Collections.ArrayList ,https://msdn.microsoft.com/en-us/library/system.collections.arraylist%28v=vs.110%29.aspx
                                                        * $Pole2D = New-Object 'object[,]' 20,4
                                                        * [System.Management.Automation.PSObject[]]$AnswerForCustomerText = @()
                                                        * [ValidateRange(1,9)][int]$x = 1
#>
$B = [boolean]
$I = [int]
[Byte]$LogFileMsgIndent = 0
$FormerPsWindowTitle = [String]
[uint64]$OutProcessedRecordsI = 0
$PauseSeconds = [Byte]
$S = [string]
[Byte]$StartChecksOK = 0
$ThisAppDuration = [TimeSpan]
$ThisAppStopTime = [datetime]
$UrlBegin = [string]
$UrlType = [Byte]

#region Functions

# ***************************************************************************
# ***|   Declaration of FUNCTIONS   |****************************************
# ***************************************************************************




















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
#>

Function Convert-AdvertisementType {
    param ( [string]$Text = '' )
    $RetVal = [string]
    $RetVal = $Text
    switch ($Text) {
        { $_ -iin 'Prodej','Prodeji','Koupi' } { $RetVal = 'Sale' }
        { $_ -iin 'Nákup','Koupit' } { $RetVal = 'Purchase' }
    }
    Return $RetVal
}



















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
#>

Function Convert-BuildingType {
    param ( [string]$Text = '' )
    $RetVal = [string]
    $RetVal = $Text
    switch ($Text) {
        { $_ -iin 'Cihla','Cihlový','Cihlová' } { $RetVal = 'Brick' }
        { $_ -iin 'Panel','Panelový','Panelová' } { $RetVal = 'Concrete' }
    }
    Return $RetVal
}



















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
#>

Function Convert-City {
    param ( [string]$Text = '' )
    $RetVal = [string]
    if ([string]::IsNullOrEmpty($City)) {
        $RetVal = $Text.Trim()
    } else {
        $RetVal = $City.Trim()
    }
    Return $RetVal
}



















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
#>

Function Convert-District {
    param ( [string]$Text = '', [string]$Street = '' )
    [Byte]$I = 0
    $RetVal = [string]
    $RetVal = $Text.Trim()
    if (-not([string]::IsNullOrEmpty($RetVal))) {
        $RetVal = Replace-DakrDiacritics -Text $Text
        if (-not([string]::IsNullOrEmpty($Street))) {
            switch ($Street) {
                { $_ -iin 'Okrouhlá' } { $RetVal = 'Bohunice' }
                { $_ -iin 'Bieblova' } { $RetVal = 'Cerna Pole' }
                { $_ -iin 'Charbulova','Slámova' } { $RetVal = 'Cernovice' }
                { $_ -iin 'Blatnická','Bořetická','Bzenecká','Čejkovická','Mutěnická','Pálavské náměstí','Prušánecká','Valtická','Velkopavlovická','Věstonická','Vlčnovská' } { $RetVal = 'Vinohrady' }
                { $_ -iin 'Krásného','Marie Kudeříkové','Mazourova','Souběžná' } { $RetVal = 'Julianov' }
                { $_ -iin 'Rozdrojovická' } { $RetVal = 'Kninicky' }
                { $_ -iin 'Dobrovského','Purkyňova','Skácelova','Srbská','Vackova' } { $RetVal = 'Kralovo Pole' }
                { $_ -iin 'Koniklecová','Oblá','Petra Křivky','Svážná' } { $RetVal = 'Liskovec Novy' }
                { $_ -iin 'Dunajská','Jemelkova','Okrouhlá','Osová' } { $RetVal = 'Liskovec Stary' }
                { $_ -iin 'Dědická','Ponětovická','Řípská','Tilhonova','Tuřanka' } { $RetVal = 'Slatina' }
                { $_ -iin 'Bratislavská','Cejl','Černopolní','Milady','Milady Horákové','Přadlácká','Příční','Radlas','Traubova' } { $RetVal = 'Zabrdovice' }
                { $_ -iin 'Renneská' } { $RetVal = 'Styrice' }
            }
        }
    }
    if ($Text.Length -gt $City.Length) {
        if (($Text.Substring(0,$City.Length)) -ieq $City) {
            $I = $City.Length
            if ($Text.Substring($I,1) -eq '-') { $I++ } 
            $RetVal = $Text.Substring($I, $Text.Length - $I)
        }
    }
    if ($RetVal -ieq 'Cerna') { $RetVal = 'Cerna Pole' }
    if ($RetVal -ieq 'Novy') { $RetVal = 'Liskovec Novy' }
    if ($RetVal -ieq 'Stary') { $RetVal = 'Liskovec Stary' }
    if ($RetVal -ieq 'Královo') { $RetVal = 'Kralovo Pole' }
    Return [string]($RetVal.Trim())
}




















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
#>

Function Convert-FlatStatus {
    param ( [string]$Text = '' )
    $RetVal = [string]
    $RetVal = $Text
    switch ($Text) {
        { $_ -iin 'Dobry','Dobrý' } { $RetVal = 'Good' }
    }
    Return $RetVal
}




















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
#>

Function Convert-OwnershipType {
    param ( [string]$Text = '' )
    $RetVal = [string]
    $RetVal = $Text
    switch ($Text) {
        { $_ -iin 'Druzstevni','Družstevní' } { $RetVal = 'Coop.' }
        { $_ -iin 'Osobni','Osobní' } { $RetVal = 'Private' }
    }
    Return $RetVal
}


















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
#>

Function Copy-RegExMatchValue {
    param ( $RegExInputText, [string]$RegExPattern = '', [string]$Label = '', [string]$ConvertTo = '' )
    $UI32 = [UInt32]
    $NowIsValue = [Boolean]
    [string]$RetVal = ''
    $S = [string]
    $RegExMatches = [regex]::Matches($RegExInputText, $RegExPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    # TypeName: System.Text.RegularExpressions.Match
    ForEach ($RegExMatch in $RegExMatches) {
        $RegExMatchGroups = $RegExMatch.Groups | Where-Object { $_.Success }   # TypeName: System.Text.RegularExpressions.Group
        $NowIsValue = $False
        ForEach ($RegExMatchGroup in $RegExMatchGroups) {
            if (($RegExMatchGroup.Value) -ne $null) {
                $S = ($RegExMatchGroup.Value).Trim()
                if ($NowIsValue) {
                    $RetVal = $S
                    $NowIsValue = $False
                }
                if ((Copy-String -Text $S -Type 'LEFT' -Pattern $Label) -eq $Label) {
                    $NowIsValue = $True
                }
            }
        }
    }
    if ($ConvertTo -ieq 'UInt') {
        ' ','.',',','-' | ForEach-Object { $RetVal = $RetVal.Replace($_,'') }
    }
    Return $RetVal
}




















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
#>

Function Convert-RealEstateType {
    param ( [string]$Text = '' )
    $RetVal = [string]
    $RetVal = $Text.Trim()
    switch ($Text) {
        { $_ -iin 'byt','bytu' } { $RetVal = 'Flat' }
        { $_ -iin 'dum','dům','domu' } { $RetVal = 'House' }
    }
    Return $RetVal
}



















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
#>

Function Convert-Region {
    param ( [string]$Text = '', [string]$City = '' )
    $RetVal = [string]
    $RetVal = $Text.Trim()
    if (-not([string]::IsNullOrEmpty($City))) {
        switch ($City) {
            { $_ -iin 'Brno' } { $RetVal = 'Jihomoravský kraj' }
            { $_ -iin 'Ostrava' } { $RetVal = 'Severomoravský kraj' }
            { $_ -iin 'Domažlice','Plzeň' } { $RetVal = 'Západočeský kraj' }
        }
    }
    Return $RetVal
}


















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
#>

Function Format-IdOfAdvertisement {
    param ( [string]$Text = '' )
    [string]$RetVal = ''
    if (-not([string]::IsNullOrEmpty($Text))) {
        $RetVal = ($Text).Trim()
        if ($RetVal -match $TextIsNumberRegEx) { 
            if ($RetVal.Substring(0,1) -eq '0') { $RetVal = ("'"+$RetVal) }
        }
    }
    Return $RetVal
}





















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
#>
Function Format-TextOfAdvertisement {
    param ( [string]$Text = '' )
    [string]$ReplaceWith = '…'
    [string[]]$FindWhat = @()
    $RetVal = [string]

    $RetVal = $Text.Replace($NewLine,'_') 
    $RetVal = $RetVal.Replace('Krásný byt','byt')

    $FindWhat += 'Nabízím k prodeji'
    $FindWhat += 'Nabízíme k prodeji'
    $FindWhat += 'Nabízíme prodej'
    $FindWhat += 'Nabízíme k převodu'
    $FindWhat += 'So zastúpením majiteľa ponúkame ku kúpe'
    $FindWhat += 'Jedná se o prodej'
    $FindWhat += 'Se souhlasem majitele nabízíme k prodeji'
    $FindWhat += 'Se souhlasem majitele nabízíme'
    $FindWhat += 'Se souhlasem majitele'
    $FindWhat += 'Ve výhradním zastoupení klienta Vám nabízíme ke koupi'
    $FindWhat += 'Ve výhradním zastoupení nabízíme k prodeji'
    $FindWhat += 'Ve výhradním zastoupení Vám nabízíme k prodeji'
    $FindWhat += 'Ve výhradním zastoupení majitele nabízíme k prodeji'
    $FindWhat += 'V exkluzivním zastoupení majitele nabízíme k prodeji'
    $FindWhat += 'S výhradním zastoupením majitele Vám nabízíme'
    $FindWhat += 'Na základě pověření majitele nabízíme ve výhradním zastoupení prodej'
    $FindWhat += 'Jako přímý majitel nabízím k prodeji'
    $FindWhat += 'Přímý majitel nabízí k prodeji'
    $FindWhat += 'výhradním zastoupení majitele'
    $FindWhat += 'Exkluzivně nabízíme k prodeji'
    $FindWhat += 'Exkluzivně nabízíme k'
    $FindWhat += 'Exkluzivně Vám nabízíme'

    $FindWhat += 'pěkný slunný'
    $FindWhat += 'velice pěkný'
    $FindWhat += 'Velmi pěkný'
    $FindWhat += 'Výborně dispozičně řešený'
    $FindWhat += 'krásně zrekonstruovaný'
    $FindWhat += 'velmi dobře dispozičně řešený'
    $FindWhat += 'Krásný byt'
    $FindWhat += 'útulného'

    $FindWhat += 'Pro prohlídku či další informace neváhejte a kontaktujte makléře.'
    $FindWhat += 'Pro více informací a prohlídku volejte makléři.'
    $FindWhat += 'Pro více informací a domluvení prohlídky kontaktujte makléře.'
    $FindWhat += 'Pro více informací kontaktujte makléře.'
    $FindWhat += 'Rádi Vám poskytneme bližší informace a připravíme prohlídku bytu.'
    $FindWhat += 'Prohlídka po domluvě.'
    $FindWhat += 'V prípade záujmu o prehliadku ma neváhajte kontaktovať.'
    $FindWhat += 'Těšíme se na Vás.'
    $FindWhat += 'Více info na '
    $FindWhat += 'Bližší info u RK.'
    $FindWhat += 'Více informací Vám poskytne realitní'
    $FindWhat += 'Podrobné další informace naleznete'
    $FindWhat += 'V případě zájmu o prohlídku bytu nás prosím kontaktujte'

    $FindWhat += 'V blízkém okolí se nachází veškerá občanská vybavenost'
    $FindWhat += 'V bezprostřední blízkosti se nachází veškerá občanská vybavenost'
    $FindWhat += 'Kompletní občanská vybavenost v bezprostřední blízkosti'
    $FindWhat += 'Je zde veškerá občanská vybavenost'
    $FindWhat += 'Dobrá občanská vybavenost'
    $FindWhat += 'veškerou občanskou vybaveností'
    $FindWhat += 'Velice dobrá občanská vybavenost'

    $FindWhat += 'Financování Vám zajistíme.'
    $FindWhat += 'Financování bytu lze zajistit prostřednictvím měsíčních splátek ve výši'
    $FindWhat += 'Vhodné jako investice'
    $FindWhat += 'Vhodné i jako investice'
    $FindWhat += 'Vhodné také jako investice'
    $FindWhat += 'Realitní kanceláře prosím nevolat!'
    $FindWhat += 'Realitní kanceláře nevolat'
    $FindWhat += 'RK nevolat'
    $FindWhat += 'RK NEVOLAT'

    $FindWhat += 'Byty splňují požadavky na moderní bydlení'
    $FindWhat += 'Jedná se o prodej jednotky vymezené podle zákona o vlastnictví bytů'

    $FindWhat += 'We offer to sale'

    foreach ($item in $FindWhat) {
        $RetVal = $RetVal.Replace($item,$ReplaceWith)
    }
    Return $RetVal
}




















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
#>

Function Get-EquipmentFromText {
    param ( [string]$Text = '' )
    $S = [string]
    if ([string]::IsNullOrEmpty($Text)) {
        # To-Do...
    }
}




















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
#>

Function Get-StreetFromText {
    param ( [string]$Text = '', [string]$Street = '' )
    $RetVal = [string]
    $RetVal = $Street
    if ($Street -eq '~') {
        $RegExPattern = 'ul.\s+(\w+)'
        $S = Copy-RegExMatchValue -RegExInputText $Text -RegExPattern $RegExPattern -Label 'ul.'
        if ($S.Trim() -ne '') { 
            $RetVal = $S
        } else {
            $RegExPattern = 'ulici\s+(\w+)'
            $S = Copy-RegExMatchValue -RegExInputText $Text -RegExPattern $RegExPattern -Label 'ulici'
            if ($S.Trim() -ne '') { 
                $RetVal = $S
            } else {
                $RegExPattern = 'ulice\s+(\w+)'
                $S = Copy-RegExMatchValue -RegExInputText $Text -RegExPattern $RegExPattern -Label 'ulice'
                $RetVal = $S
            }
        }
    }
    Return ($RetVal.Trim())
}





















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
#>
Function New-ObjectTemplate {
    $S = [string]
    $RetVal = New-Object -TypeName System.Management.Automation.PSObject
    $S = "{0:dd}.{0:MM}.{0:yyyy}" -f (Get-Date)
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name MyPriority -Value 100
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Price -Value ([uint32]::MinValue)
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Tax1oooCzk -Value 0
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Commission -Value 0
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name PriceTotal -Value ([uint32]::MinValue)
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Size -Value 0
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name SizePlus -Value '~'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Sizem2 -Value 0
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name SizeUnused -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name CzkPerM2 -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name OwnershipType -Value '~'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Balcony -Value '~'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Cellar -Value '~'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Kitchen -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name BathRoom -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name WC -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name BedRoom -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Childs -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Hall -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Room1 -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Room2 -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Room3 -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Garage -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name RoomsM2Unused -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name FurnitureKitchen -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name FurnitureBathRoom -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name FurnitureBedRoom -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name FurnitureLivingRoom -Value ''    
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name FlatStatus -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Street -Value '~'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name District -Value '~'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Floor -Value 999
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name FloorTotal -Value '?'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name BuildingType -Value '~'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name BuildingStatus -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name BuildingAge -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name BuildingLift -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name BuildingBicycle -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name BuildingDrying -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name BuildingCourtyard -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name EnergyClass -Value 'X'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name EnergyKWhPerM2PerYear -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name MediaGas -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name MediaElectricity -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name MediaWarmWater -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name MediaHeating -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name MonthlyCzkGas -Value 0
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name MonthlyCzkElectricity -Value 0
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name MonthlyCzkRepairFond -Value 0
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name MonthlyCzkOther -Value 0
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name MonthlyCzkAvgTotal -Value 0
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name MonthlyCzkNotes -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name InternetNetBox -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name InternetUPC -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name InternetOther -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name AvailableFromDate -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name SellerPhone -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name SellerEmail -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name URL -Value '~'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name ID -Value '-1'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name FeeCZK -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name TV -Value 'No'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Furnishings -Value '~'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Terrace -Value '~'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name City -Value '~'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Region -Value '~'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name WWWSource -Value '~'   # Real Estate Agency
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name AdvertisementType -Value '~'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name RealEstateType -Value '~'
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Inserted -Value $S
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name FirstAnnounceDate -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name LastUpdate -Value ''
    Add-Member -InputObject $RetVal -MemberType NoteProperty -Name Text -Value ([string]::Empty)
    $RetVal
}




















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
Help: 
  * How to return multiple values from Powershell function : http://martinzugec.blogspot.sk/2009/08/how-to-return-multiple-values-from.html
  $wc = New-Object -TypeName System.Net.WebClient   # WebClient.DownloadFile Method : https://msdn.microsoft.com/en-us/library/ez801hhe%28v=vs.110%29.aspx
            #$Html = $WebRequestRetVal.ParsedHtml
#>

Function Get-BezRealitkyCz {
    param ( [string]$URL = '' )
    [string[]]$Address = @()
    [string[]]$CityDistrict = @()
    $I = [uint32]
    $X = [uint32]
    $Pattern = [string]
    $PatternLength = [uint32]
    $S = [string]
    [string]$TextFull = ''
    [string]$TextShort = ''
    [string]$RowCity = ''
    $script:LogFileMsgIndent = Set-DakrLogFileMessageIndent -Level $LogFileMsgIndent -Increase
    $WebRequestRetVal = Invoke-WebRequest -URI $URL -UseDefaultCredentials
    # $WebRequestRetVal = TypeName: Microsoft.PowerShell.Commands.HtmlWebResponseObject
    if ($WebRequestRetVal) {
        if ($WebRequestRetVal.StatusCode -eq 200) {
            Write-DakrHostWithFrame -Message "Web-Request Status = $($WebRequestRetVal.StatusDescription)"
            # $WebRequestRetVal | Out-File -Encoding UTF8 -FilePath "$OutputFile.WebRequestObject"
            $Row = New-ObjectTemplate
            $I = 0
            $WebRequestRetVal.AllElements | Where-Object { ($_.TagName -ieq 'DIV') -and ($_.class -ieq 'row') } | ForEach-Object {
                $I++
                $OuterText = ($_.outerText)

                $Pattern = 'číslo inzerátu:'
                $PatternLength = $Pattern.Length
                if ($OuterText.Length -gt $PatternLength) {
                    if ($OuterText.Substring(0,$PatternLength) -ieq $Pattern) {
                        $Row.ID = $OuterText.Substring(($PatternLength+2), $OuterText.Length-($PatternLength+2))
                    }
                }
                $Pattern = 'typ budovy:'
                $PatternLength = $Pattern.Length
                if ($OuterText.Length -gt $PatternLength) {
                    if ($OuterText.Substring(0,$PatternLength) -ieq $Pattern) {
                        $S = $OuterText.Substring(($PatternLength+2), $OuterText.Length-($PatternLength+2))
                        $Row.BuildingType = Convert-BuildingType -Text $S
                    }
                }
                $Pattern = 'energetická třída:'
                $PatternLength = $Pattern.Length
                if ($OuterText.Length -gt $PatternLength) {
                    if ($OuterText.Substring(0,$PatternLength) -ieq $Pattern) {
                        $Row.EnergyClass = $OuterText.Substring(($PatternLength+2), $OuterText.Length-($PatternLength+2))
                    }
                }
                $Pattern = 'dostupnost TV:'
                $PatternLength = $Pattern.Length
                if ($OuterText.Length -gt $PatternLength) {
                    if ($OuterText.Substring(0,$PatternLength) -ieq $Pattern) {
                        $Row.TV = $OuterText.Substring(($PatternLength+2), $OuterText.Length-($PatternLength+2))
                    }
                }
                $Pattern = 'typ nabídky:'
                $PatternLength = $Pattern.Length
                if ($OuterText.Length -gt $PatternLength) {
                    if ($OuterText.Substring(0,$PatternLength) -ieq $Pattern) {
                        $Row.AdvertisementType = Convert-AdvertisementType -Text ($OuterText.Substring(($PatternLength+2), $OuterText.Length-($PatternLength+2)))
                    }
                }
                $Pattern = 'typ nemovitosti:'
                $PatternLength = $Pattern.Length
                if ($OuterText.Length -gt $PatternLength) {
                    if ($OuterText.Substring(0,$PatternLength) -ieq $Pattern) {
                        $Row.RealEstateType = Convert-RealEstateType -Text ($OuterText.Substring(($PatternLength+2), $OuterText.Length-($PatternLength+2)))
                    }
                }
                $Pattern = 'dispozice:'
                $PatternLength = $Pattern.Length
                if ($OuterText.Length -gt $PatternLength) {
                    if ($OuterText.Substring(0,$PatternLength) -ieq $Pattern) {
                        $S = $OuterText.Substring(($PatternLength+2), $OuterText.Length-($PatternLength+2))
                        $SizeXPlus = $S.Split('+')
                        if ($SizeXPlus.Length -gt 0) {
                            Try { $Row.Size = [uint16]($SizeXPlus[0]) } Catch { $Row.Size = $SizeXPlus[0] }
                            $Row.SizePlus =  $SizeXPlus[1]
                        } else {
                            $Row.Size = 0
                            $Row.SizePlus = $S
                        }
                    }
                }
                $Pattern = 'plocha:'
                $PatternLength = $Pattern.Length
                if ($OuterText.Length -gt $PatternLength) {
                    if ($OuterText.Substring(0,$PatternLength) -ieq $Pattern) {
                        $X = $PatternLength + 2
                        if ($OuterText.Length -ge ($X + 3)) { $X += 3 }
                        $S = $OuterText.Substring(($PatternLength+2), $OuterText.Length-$X)
                        Try { $Row.Sizem2 = [uint16]$S } Catch { $Row.Sizem2 = $S }
                    }
                }
                $Pattern = 'cena:'
                $PatternLength = $Pattern.Length
                if ($OuterText.Length -gt $PatternLength) {
                    if ($OuterText.Substring(0,$PatternLength) -ieq $Pattern) {
                        $X = $PatternLength + 2
                        if ($OuterText.Length -ge ($X + 3)) { $X += 3 }
                        $S = $OuterText.Substring(($PatternLength+2), $OuterText.Length-$X)
                        $S = $S.Replace('.','')
                        Try { $Row.Price = [uint32]([math]::Truncate($S/1000)) } Catch { $Row.Price = $S }
                    }
                }
                $Pattern = 'typ vlastnictví:'
                $PatternLength = $Pattern.Length
                if ($OuterText.Length -gt $PatternLength) {
                    if ($OuterText.Substring(0,$PatternLength) -ieq $Pattern) {
                        $S = $OuterText.Substring(($PatternLength+2), $OuterText.Length-($PatternLength+2))
                        $Row.OwnershipType = Convert-OwnershipType -Text $S
                    }
                }
                $Pattern = 'vybavení:'
                $PatternLength = $Pattern.Length
                if ($OuterText.Length -gt $PatternLength) {
                    if ($OuterText.Substring(0,$PatternLength) -ieq $Pattern) {
                        $Row.Furnishings = $OuterText.Substring(($PatternLength+2), $OuterText.Length-($PatternLength+2))
                    }
                }
                $Pattern = 'podlaží:'
                $PatternLength = $Pattern.Length
                if ($OuterText.Length -gt $PatternLength) {
                    if ($OuterText.Substring(0,$PatternLength) -ieq $Pattern) {
                        $Row.Floor = $OuterText.Substring(($PatternLength+2), $OuterText.Length-($PatternLength+2))
                    }
                }
                $Pattern = 'balkón:'
                $PatternLength = $Pattern.Length
                if ($OuterText.Length -gt $PatternLength) {
                    if ($OuterText.Substring(0,$PatternLength) -ieq $Pattern) {
                        $S = $OuterText.Substring(($PatternLength+2), $OuterText.Length-($PatternLength+2))
                        if (Test-DakrTextIsBooleanTrue -Text $S) {
                            $Row.Balcony = '1'
                        } else {
                            $Row.Balcony = ''                              
                        }
                    }
                }
                $Pattern = 'terasa:'
                $PatternLength = $Pattern.Length
                if ($OuterText.Length -gt $PatternLength) {
                    if ($OuterText.Substring(0,$PatternLength) -ieq $Pattern) {
                        $Row.Terrace = $OuterText.Substring(($PatternLength+2), $OuterText.Length-($PatternLength+2))
                    }
                }
            }
            $WebRequestRetVal.AllElements | Where-Object { ($_.TagName -ieq 'DIV') -and ($_.class -ieq 'short') } | ForEach-Object {
                $I++
                $OuterText = ($_.outerText)
                $TextShort = $OuterText.Trim()
            }
            $WebRequestRetVal.AllElements | Where-Object { ($_.TagName -ieq 'DIV') -and ($_.class -ieq 'full') } | ForEach-Object {
                $I++
                $OuterText = ($_.outerText)
                $TextFull = $OuterText.Trim()
            }
            if ($TextFull.Length -gt $TextShort.Length) {
                $Row.Text = $TextFull
            } else {
                $Row.Text = $TextShort
            }
            $Row.Text = Format-TextOfAdvertisement -Text ($Row.Text)
            $WebRequestRetVal.AllElements | Where-Object { ($_.TagName -ieq 'DIV') -and ($_.class -ieq 'key') } | ForEach-Object {
                $I++
                $OuterText = ($_.outerText)
                if ($OuterText -ieq 'UPC dostupné!:') {
                    $Row.InternetUPC = 'Y'
                }
            }
            $WebRequestRetVal.AllElements | Where-Object { ($_.TagName -ieq 'H2') } | ForEach-Object {
                $I++
                $OuterText = ($_.outerText)
                if (($OuterText.Contains(',')) -and ($OuterText.Contains('kraj'))) {
                    $Address = $OuterText.Split(',')
                    if ($Address.Length -gt 0) { $Row.Street = ($Address[0]).Trim() }
                    if ($Address.Length -gt 1) { 
                        $S = ($Address[1]).Trim()
                        $CityDistrict = $S.Split('-')
                        if ($CityDistrict.Length -gt 0) { $Row.City     = Convert-City -Text ($CityDistrict[0]) }
                        if ($CityDistrict.Length -gt 1) { $Row.District = Convert-District -Text ($CityDistrict[1]) -Street ($Row.Street) }
                    }
                    if ($Address.Length -gt 2) { $Row.Region = ($Address[2]).Trim() }
                    # $OuterText | Out-File -Encoding UTF8 -FilePath "$OutputFile.$I"
                }
            }
            $Row.Cellar = ''
            if (($Row.Text).Contains('sklep')) { $Row.Cellar = '1' }
            $Row.Street = Get-StreetFromText -Text ($Row.Text) -Street ($Row.Street)
            $RowCity = ($Row.City)
            $Row.Region = Convert-Region -Text ($Row.Region) -City $RowCity
            Get-EquipmentFromText -Text ($Row.Text)
            $Row.Commission = 0
            $Row.WWWSource = 'BezRealitky.Cz'
            $Row.URL = $URL
            $Row.MyPriority = Set-MyPriority -Rec $Row
            $Row.ID = Format-IdOfAdvertisement -Text $Row.ID
            
            $Row | Format-Table -AutoSize -Property $FormatTableProperties
            $Row | Export-Csv -Path $OutputFile -Encoding UTF8 -Delimiter "`t" -NoTypeInformation -Append
        }
    }
    $script:LogFileMsgIndent = Set-DakrLogFileMessageIndent -Level $LogFileMsgIndent
}




















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
#>

Function Get-SeznamRealityCz {
    param ( [string]$URL = '' )
    $script:LogFileMsgIndent = Set-DakrLogFileMessageIndent -Level $LogFileMsgIndent -Increase
    [string[]]$Address = @()
    $B = [Boolean]
    [string[]]$CityDistrict = @()
    $I = [uint32]
    $IB = [uint32]
    $X = [uint32]
    $Pattern = [string]
    $PatternLength = [uint32]
    $Price = [Double]
    $RegExPattern = [string]
    $S = [string]
    [string]$TextFull = ''
    [string]$TextShort = ''
    $script:LogFileMsgIndent = Set-DakrLogFileMessageIndent -Level $LogFileMsgIndent -Increase
    $ClipboardText = [Windows.Clipboard]::GetText()
    <#
                            $ClipboardText = `
                            '   Prodej bytu 2+kk 44 m² Bednaříkova, Brno - Líšeň
                                2 000 000 Kč

                                Se souhlasem majitele výhradně nabízíme prodej (převod) družstevního bytu o dispozici 2+kk v Brně v městské části Líšeň na ulici Bednaříkova s možností převodu do OV.Jedná se o byt,který se nachází ve třetím patře panelového domu s výtahem.Celková plocha bytu činí 44 m2.Byt je ve velmi udržovaném stavu ihned k užívání.Byt má plastová okna.Měsíční náklady zde činí cca 3.000,-Kč (fond oprav vč.služeb a inkasa).V bytě je zabudovaný nábytek na míru,dále kuchyňská linka na míru vč.spotřebičů značky AEG.V bytě jsou rozvody el.230/400 V.Parkování je zde bezproblémové před domem.K bytu náleží sklep.Bytový dům prošel kompletní revitalizací.V městské části Brno-Líšeň je veškerá občanská vybavenost.Dostupnost do centra města zajišťují pravidelné linky MHD cca každých 5 min.

                                    Celková cena: 2 000 000 Kč za nemovitost, + provize RK, včetně poplatků, včetně právního servisu
                                    Hypotéka: 4 158,97 Kč měsíčně 

                                    Náklady na bydlení: 3.000,-Kč fond oprav vč.služeb a inkasa
                                    ID zakázky: 243
                                    Aktualizace: Dnes Inzerát byl dnes topován
                                    Stavba: Panelová
                                    Stav objektu: Dobrý
                                    Vlastnictví: Družstevní
                                    Převod do OV: Ano
                                    Umístění objektu: Klidná část obce
                                    Podlaží: 4. podlaží z celkem 9 včetně 1 podzemního
                                    Užitná plocha: 44 m2
                                    Plocha podlahová: 44 m2

                                    Sklep:
                                    Parkování:
                                    Voda: Dálkový vodovod
                                    Topení: Ústřední dálkové
                                    Odpad: Veřejná kanalizace
                                    Telekomunikace: Telefon, Internet, Satelit, Kabelová televize, Kabelové rozvody, Ostatní
                                    Elektřina: 230V, 400V
                                    Doprava: Silnice, MHD, Autobus
                                    Komunikace: Asfaltová
                                    Energetická náročnost budovy: Třída C - Úsporná
                                    Výtah:'
    #>
    if ($ClipboardText) {
        # $ClipboardText = ($ClipboardText.Replace(' ', '')).Trim()
        $ClipboardText = $ClipboardText.Trim()
        $Row = New-ObjectTemplate
        $I = 0
        $RegExPattern = '^\s*Prodej bytu (\d\+\w+)'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'Prodej bytu '
        $SizeXPlus = $S.Split('+')
        if ($SizeXPlus.Length -gt 0) {
            Try { $Row.Size = [uint16]($SizeXPlus[0]) } Catch { $Row.Size = $SizeXPlus[0] }
            $Row.SizePlus =  $SizeXPlus[1]
        } else {
            $Row.Size = 0
            $Row.SizePlus = $S
        }
        $RegExPattern = '(\d{1,3}([\s,.]?\d{1,3})*)'
        $RegExPattern = "Celková cena: $RegExPattern Kč"
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'Celková cena:' -ConvertTo 'UInt'
        Try { 
            $Price = [Double]$S
            $Row.Price = [uint32]([math]::Truncate($Price/1000)) 
        } Catch { 
            $Row.Price = $S 
        }
        $RegExPattern = 'm² (\w+)'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'm²'
        if (($S.Trim()) -ieq 'Brno') { $Row.Street = 'unknown' } else { $Row.Street = $S }
        $RegExPattern = ',\s+(\w+)\s+-\s+'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label ','
        $Row.City = Convert-City -Text $S
        $RegExPattern = '\s*Brno - ([\w-]+)'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'Brno - '
        $Row.District = Convert-District -Text $S -Street ($Row.Street)
        $RegExPattern = 'ID zakázky: ([\w\d]+)'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'ID zakázky:'
        $Row.ID = Format-IdOfAdvertisement -Text $S
        $RegExPattern = 'Aktualizace: (\w+)'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'Aktualizace:'
        if ($S -ieq 'Dnes') { 
            $Row.LastUpdate = '{0:dd}.{0:MM}.{0:yyyy}' -f (Get-Date) 
        } else {
            Try { $Row.LastUpdate = [DateTime]::Parse($S, $(Get-culture)) } Catch { $Row.LastUpdate = '' }
        }
        $RegExPattern = 'Stavba: (\w+)'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'Stavba:'
        $Row.BuildingType = Convert-BuildingType -Text $S
        $RegExPattern = 'Stav objektu: (\w+)'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'Stav objektu:'
        $Row.FlatStatus = Convert-FlatStatus -Text $S
        $RegExPattern = 'Vlastnictví: (\w+)'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'Vlastnictví:'
        $Row.OwnershipType = Convert-OwnershipType -Text $S
        $RegExPattern = 'Podlaží: (\d{1,3})'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'Podlaží:' -ConvertTo 'UInt'
        Try { $Row.Floor = [uint32]$S } Catch { $Row.Floor = $S }
        $RegExPattern = 'podlaží z celkem (\d{1,3})'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'podlaží z celkem' -ConvertTo 'UInt'
        Try { $Row.FloorTotal = [uint32]$S } Catch { $Row.FloorTotal = $S }
        $RegExPattern = 'Užitná plocha: (\d{1,3}) m2'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'Užitná plocha:' -ConvertTo 'UInt'
        Try { $Row.Sizem2 = [uint32]$S } Catch { $Row.Sizem2 = $S }
        $RegExPattern = 'Elektřina: (\w+)'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'Elektřina:'
        $Row.MediaElectricity = $S
        $RegExPattern = 'Topení: (\w+)'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'Topení:'
        $Row.MediaHeating = $S
        $RegExPattern = 'Energetická náročnost budovy: Třída (\w+)'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'Energetická náročnost budovy: Třída'
        $Row.EnergyClass = $S
        $RegExPattern = 'Výtah: (\w+)'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'Výtah:'
        if (Test-DakrTextIsBooleanTrue -Text $S) {
            $Row.BuildingLift = 'Y'
        } else {
            $Row.BuildingLift = 'N'                              
        }
        $RegExPattern = 'Sklep: (\w+)'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'Sklep:'
        if (Test-DakrTextIsBooleanTrue -Text $S) {
            $Row.Cellar = 'Y'
        } else {
            $Row.Cellar = 'N'                              
        }
        $RegExPattern = 'Telekomunikace: (\w+)'
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'Telekomunikace:'
        $Row.InternetOther = $S
        $RegExPattern = '(\d{1,3}([\s,.]?\d{1,3})*),-Kč'
        $RegExPattern = "Náklady na bydlení: $RegExPattern"
        $S = Copy-RegExMatchValue -RegExInputText $ClipboardText -RegExPattern $RegExPattern -Label 'Náklady na bydlení:' -ConvertTo 'UInt'
        Try { $Row.MonthlyCzkAvgTotal = [uint32]$S } Catch { $Row.MonthlyCzkAvgTotal = $S }
        $I = $ClipboardText.IndexOf(' Kč')
        $X = $ClipboardText.IndexOf('Celková cena: ')
        if (($I -gt 0) -and ($X -gt $I)) {
            $Row.Text = ($ClipboardText.Substring($I+3, ($X-$I-3))).Trim()
        }
        $Row.Text = Format-TextOfAdvertisement -Text ($Row.Text)
        if (($Row.Text).Contains('sklep')) { $Row.Cellar = '1' }
        $Row.Street = Get-StreetFromText -Text ($Row.Text) -Street ($Row.Street)
        $Row.Region = Convert-Region -Text ($Address[2]) -City ($Row.City)
        
        $Row.AdvertisementType = Convert-AdvertisementType -Text 'Sale'
        $Row.RealEstateType = Convert-RealEstateType -Text 'Flat'
        $Row.Commission = 0
        $Row.WWWSource = 'SReality.Cz'
        $Row.URL = 'http://www.sreality.cz/detail/prodej/byt/.../.../'+($Row.ID)+'#img=0&fullscreen=false'
        $Row.MyPriority = Set-MyPriority -Rec $Row

        $Row | Format-Table -AutoSize -Property $FormatTableProperties
        $Row | Export-Csv -Path $OutputFile -Encoding UTF8 -Delimiter "`t" -NoTypeInformation -Append
    }
    [Windows.Clipboard]::Clear()
    $script:LogFileMsgIndent = Set-DakrLogFileMessageIndent -Level $LogFileMsgIndent
}













<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
Help: 
  * How to return multiple values from Powershell function : http://martinzugec.blogspot.sk/2009/08/how-to-return-multiple-values-from.html
#>

Function Get-WWWSource {
    $S = [string]
    $script:LogFileMsgIndent = Set-DakrLogFileMessageIndent -Level $LogFileMsgIndent -Increase
    if (-not([string]::IsNullOrEmpty($InputFile))) {
        if (Test-Path -Path $InputFile -PathType Leaf) {
            Get-Content -Path $InputFile -Encoding UTF8 | ForEach-Object {
                if (-not([string]::IsNullOrEmpty($_))) {
                    $S = ($_).Trim()
                    if ((($S).Substring(0,1)) -ne '#') { $URLs += $S }
                }
            }
        }
    }
	$script:ShowProgressMaxSteps = $URLs.Length

    foreach ($URL in $URLs) {
	    $OutProcessedRecordsI++
	    Show-DaKrProgress -StepsCompleted $OutProcessedRecordsI -StepsMax $ShowProgressMaxSteps -NoOutput2ScreenPar:$NoOutput2Screen.IsPresent
        $UrlBegin = 'https://www.bezrealitky.cz/'
        if ($URL.length -gt $UrlBegin.length) {
            for ($UrlType = 1; $UrlType -lt 3; $UrlType++) { 
                if ($URL.Substring(0,$UrlBegin.length) -ieq $UrlBegin) {
                    Get-BezRealitkyCz -URL $URL
                }
                $UrlBegin = $UrlBegin.Replace('https:','http:')                
            }
        }
        $UrlBegin = 'http://www.sreality.cz/'
        if ($URL.length -gt $UrlBegin.length) {
            if ($URL.Substring(0,$UrlBegin.length) -ieq $UrlBegin) {
                Get-SeznamRealityCz -URL $URL
            }
        }
        if (-not($NoSound.IsPresent)) { Write-Host `a -NoNewline }
        if ($PauseMax -gt 0) { 
            if ($PauseMin -eq $PauseMax) {
                Start-Sleep -Seconds $PauseMax
            }
            if ($PauseMin -lt $PauseMax) {
                $PauseSeconds = [math]::Truncate( (Get-Random -Minimum $PauseMin -Maximum $PauseMax) )
                Write-DakrHostWithFrame -Message "I am sleeping for $PauseSeconds seconds..."
                Start-Sleep -Seconds $PauseSeconds
            }
        }
    }
    $script:LogFileMsgIndent = Set-DakrLogFileMessageIndent -Level $LogFileMsgIndent
}


















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |

These codes may be used with the -d option.
%a     Locale's abbreviated weekday name.
%A     Locale's full weekday name.
%b     Locale's abbreviated month name.
%B     Locale's full month name.
%c     Locale's appropriate date and time representation.
%d     Day of the month as a decimal number [01,31].
%H     Hour (24-hour clock) as a decimal number [00,23].
%I     Hour (12-hour clock) as a decimal number [01,12].
%j     Day of the year as a decimal number [001,366].
%m     Month as a decimal number [01,12].
%M     Minute as a decimal number [00,59].
%p     Locale's equivalent of either AM or PM.
%S     Second as a decimal number [00,61].
%U     Week number of the year (Sunday as the first day of the week)
          as a decimal number [00,53]. All days in a new year preceding
          the first Sunday are considered to be in week 0
%w     Weekday as a decimal number [0(Sunday),6].
%W     Week number of the year (Monday as the first day of the week)
          as a decimal number [00,53]. All days in a new year preceding
          the first Monday are considered to be in week 0.
%x     Locale's appropriate date representation.
%X     Locale's appropriate time representation.
%y     Year without century as a decimal number [00,99].
%Y     Year with century as a decimal number.
%Z     Time zone name (no characters if no time zone exists).
%%     A literal "%" character.#>

Function Import-OutputCsvToOdsFile {
	[String]$CmdScript = ''
	[String]$S = ''
    [String[]]$ArgumentList = @()
    [String]$PythonExeFile = ''
    [String]$Csv2OdfPythonFile = (($env:Folder_PortableBin)+'\Csv2Odf\csv2odf')
    $script:LogFileMsgIndent = Set-DakrLogFileMessageIndent -Level $LogFileMsgIndent -Increase

    if (-not (Test-Path -Path $OutputFile -PathType Leaf)) { 
        Get-ChildItem -Path $OutputFile
        Break 
    }
    if ([string]::IsNullOrEmpty($ImportToOdsFileLibreOffice)) {
        Get-Item -Path $OutputFile | ForEach-Object {
            $ImportToOdsFileLibreOffice = ($_.DirectoryName)+'\'+($_.BaseName)+'.ods'
            $CmdScript = ($_.DirectoryName)+'\'+($_.BaseName)+'.CMD'
        }
    }
    $FindFileForSwRetVal = Find-FileForSw -SW 'PYTHON' -MinSize (26*1kb) -StopAfter 1
    if ($FindFileForSwRetVal -ne $null) {
        $PythonExeFile = $FindFileForSwRetVal.FullName
    }
    if (-not(Test-Path -Path $PythonExeFile -PathType Leaf)) { Break }
    if (-not(Test-Path -Path $Csv2OdfPythonFile -PathType Leaf)) { Break }
    if (-not(Test-Path -Path $ImportToOdsFileTemplate -PathType Leaf)) { Break }
    if (Test-Path -Path $ImportToOdsFileLibreOffice -PathType Leaf) { Remove-Item -Path $ImportToOdsFileLibreOffice }
    $ArgumentList += Add-QuotationMarks -QuotationMark '"' -Text $Csv2OdfPythonFile
    $ArgumentList += '-v'
    $ArgumentList += '-c \t'
    $ArgumentList += '-s 2'
    $ArgumentList += '-d "%d.%m.%Y"'
    $ArgumentList += "--input=$OutputFile"
    $ArgumentList += $ImportToOdsFileTemplate   # '--template=' doesn't work in current version (2.04) : https://sourceforge.net/p/csv2odf/bugs/6/
    $ArgumentList += "--output=$ImportToOdsFileLibreOffice"
    '@echo OFF' | Out-File -FilePath $CmdScript -Encoding ascii -Force
    "echo $('_'*100)" | Out-File -FilePath $CmdScript -Encoding ascii -Append
    $S = Add-QuotationMarks -QuotationMark '"' -Text $PythonExeFile
    "$S $(Add-QuotationMarks -QuotationMark '"' -Text $Csv2OdfPythonFile) -V" | Out-File -FilePath $CmdScript -Encoding ascii -Append
    'echo.' | Out-File -FilePath $CmdScript -Encoding ascii -Append
    $ArgumentList | ForEach-Object {
        $S += " $_"
    }
    $S | Out-File -FilePath $CmdScript -Encoding ascii -Append
    $S = Split-Path -Path $OutputFile -Parent
    Start-Process -FilePath $PythonExeFile -Wait -NoNewWindow -ArgumentList $ArgumentList -WorkingDirectory $S
    Invoke-Item -Path $ImportToOdsFileLibreOffice -Verbose
    $script:LogFileMsgIndent = Set-DakrLogFileMessageIndent -Level $LogFileMsgIndent
}


















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
#>

Function Set-MyPriority {
	param( $Rec = [System.Management.Automation.PSObject])
	[uint16]$RetVal = 100
    $script:LogFileMsgIndent = Set-DakrLogFileMessageIndent -Level $LogFileMsgIndent -Increase
    if ($Rec.District -in 'Lesna','Lisen','Zidenice') {
        $RetVal += 50
    }
    if ($Rec.District -in 'Slatina','Cernovice') {
        $RetVal += 20
    }
    if ($Rec.Price -gt 2900) {
        $RetVal -= 50
    }
    $script:LogFileMsgIndent = Set-DakrLogFileMessageIndent -Level $LogFileMsgIndent
	Return $RetVal
}


















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
Help: 
  * How to return multiple values from Powershell function : http://martinzugec.blogspot.sk/2009/08/how-to-return-multiple-values-from.html
#>

Function XXX-Template {
	param( [string]$P = '' )
	[String]$RetVal = ''
    $script:LogFileMsgIndent = Set-DakrLogFileMessageIndent -Level $LogFileMsgIndent -Increase
    # To-Do ...
    $script:LogFileMsgIndent = Set-DakrLogFileMessageIndent -Level $LogFileMsgIndent
	Return $RetVal
}




















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
Help: 
#>

Function Show-HelpForEndUser {
    Show-DakrHelpForUser -Header
	Write-DakrHostWithFrame 'Parameters for this script:'
	$I = 1
	Write-DakrHostWithFrame "$I.To-Do... = you have to enter To-Do... ."
	$I++
	Write-DakrHostWithFrame "$I.help = you can use it for show this documentation."
	$I++
	Write-DakrHostWithFrame "$I.DebugLevel = Default value is 0."
	Write-DakrHostWithFrame '                        '
	Write-DakrHostWithFrame '                        '
	Write-DakrHostWithFrame 'You can use it inside of PowerShell by this way:'
	Write-DakrHostWithFrame " .\$ThisAppName -help -DebugLevel 1"
    Show-DakrHelpForUser -Footer
}





















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
Help: 
    * SwitchParameter Structure : https://msdn.microsoft.com/en-us/library/system.management.automation.switchparameter(v=vs.85).aspx
    * $NewLines += '$Help = New-Object -TypeName Management.Automation.SwitchParameter'
#>

Function Update-ParametersByConfigFile {
    Param ([string]$FileName = '')
    [string]$EmptyString = "''"
    [string[]]$NewLines = @()
    [boolean]$RetVal = $False
    if (-not ([string]::IsNullOrEmpty($FileName))) {
        If (Test-Path -Path $FileName -PathType Leaf ) { 
            & $FileName
            $RetVal = $False
        } else {
            $NewLines += '$DebugLevel = 0'
            $NewLines += '$Help = $False'
            $NewLines += '$NoOutput2Screen = $False'
            $NewLines += '$NoSound = $False'
            $NewLines += '$LogFile = '+$EmptyString
            $NewLines += '$OutputFile = '+$EmptyString
            $NewLines += '$RunFromSW = '+$EmptyString
            $NewLines += '$PSWindowWidth = 0'
            foreach ($Line in $NewLines) {
                ($Line.Trim()) | Out-File -Append -FilePath $FileName -Encoding utf8
            }
            $RetVal = $True
        }
    }
    Return $RetVal
}





















<#
|                                                                                          |
\__________________________________________________________________________________________/
 ##########################################################################################
 ##########################################################################################
/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|                                                                                          |
Help: 
#>

Function Write-ParametersToLog {
    [int]$I = 30
    $script:LogFileMsgIndent = Set-DakrLogFileMessageIndent -Level $LogFileMsgIndent -Increase
    Write-DakrInfoMessage -ID $($I+1) -Message "Input parameters: NoOutput2Screen=$($NoOutput2Screen.IsPresent) ."
    Write-DakrInfoMessage -ID $($I+2) -Message "Input parameters: DebugLevel=$DebugLevel ."
    Write-DakrInfoMessage -ID $($I+3) -Message "Input parameters: LogFile=$LogFile ."
    Write-DakrInfoMessage -ID $($I+4) -Message "Input parameters: InputFile=$InputFile ."
    Write-DakrInfoMessage -ID $($I+5) -Message "Input parameters: PauseMin=$PauseMin ."
    Write-DakrInfoMessage -ID $($I+6) -Message "Input parameters: PauseMax=$PauseMax ."
    Write-DakrInfoMessage -ID $($I+7) -Message "Input parameters: OutputDataOnly=$OutputDataOnly ."
    Write-DakrInfoMessage -ID $($I+8) -Message "Input parameters: City=$City ."
    Write-DakrInfoMessage -ID $($I+9) -Message "Input parameters: ImportToOdsFile=$($ImportToOdsFile.IsPresent) ."
    Write-DakrInfoMessage -ID $($I+10) -Message "Input parameters: ImportToOdsFileTemplate=$ImportToOdsFileTemplate ."
    Write-DakrInfoMessage -ID $($I+11) -Message "Input parameters: ImportToOdsFileLibreOffice=$ImportToOdsFileLibreOffice ."
    Write-DakrInfoMessage -ID $($I+12) -Message "Input parameters: OutputFile=$OutputFile ."
    foreach ($item in $URLs) {
        Write-DakrInfoMessage -ID $($I+13) -Message "Input parameters: URLs=$item ."
    }
    $script:LogFileMsgIndent = Set-DakrLogFileMessageIndent -Level $LogFileMsgIndent
}

# ***************************************************************************


#endregion Functions

#region TemplateMain

















# ***************************************************************************
# ***|  Main, begin, start, body, zacatek, Entry point  |********************
# ***************************************************************************

Push-Location
Try {
    Test-DakrLibraryVersion -Version 11 | Out-Null
} Catch [System.Exception] {
    Remove-Module -Name DavidKriz -ErrorAction SilentlyContinue
} Finally {
    if (([int]((Get-Host).Version).Major) -gt 2) {
        Import-Module -Name DavidKriz -ErrorAction Stop -DisableNameChecking -Prefix Dakr
    } else {
        Import-Module -Name DavidKriz -ErrorAction Stop -DisableNameChecking -Prefix Dakr
    }
    # Get-Module -Name DavidKriz | Format-Table -AutoSize -Property Name,Path
}
$LogFile = New-DakrLogFileName -Path $LogFile -ThisAppName $ThisAppName
    Write-Debug "Log File = $LogFile"
Set-DakrModuleParametersV2 -inLogFile $LogFile -inNoOutput2Screen ($OutputDataOnly.IsPresent -or $NoOutput2Screen.IsPresent) -inOutputFile $OutputFile -inThisAppName $ThisAppName -inThisAppVersion $ThisAppVersion -inPSWindowWidth $PSWindowWidthI -inRunFromSW $RunFromSW
$DavidKrizModuleParams = Get-DakrModuleParameters
$HostRawUI = (Get-Host).UI.RawUI
$FormerPsWindowTitle = $HostRawUI.WindowTitle
$HostRawUI.WindowTitle = $ThisAppName
Write-DakrHostHeaderV2 -Header

if ($DebugLevel -gt 0) {
  Write-Debug "DebugLevel = $DebugLevel , PowerShell Version = $PowerShellVersionS "
}

if (Test-DakrLibraryVersion -Version 321 ) { Break }

# ...........................................................................................
# I N P U T   P A R A M E T E R s :
if ( $help -eq $true ) {
	Show-HelpForEndUser
	Break
} else {
    Write-ParametersToLog
    if ((Update-ParametersByConfigFile -FileName $ConfigFile) -eq $True) { Break }
    $OutputFile = Replace-DakrDotByCurrentLocation -Path $OutputFile
}
#endregion TemplateMain

if ($true) { $StartChecksOK++ }


#Try {

#endregion TemplateBegin

    if ($StartChecksOK -ge 1) {
        # $ShowProgressMaxSteps = [int]($File | Measure-Object -Line).Lines
        if ([string]::IsNullOrEmpty($OutputFile)) {
            $OutputFile = "$($env:USERPROFILE)\Documents\Update-AdvertisementDatabase___{0:yyyy}-{0:MM}-{0:dd}.Tsv" -f (Get-Date)
        }
        if ([string]::IsNullOrEmpty($InputFile)) {
            $InputFile = "$($env:USERPROFILE)\_PUB\HOUSING\New\Update-AdvertisementDatabase.txt"
        }
        Get-WWWSource
        if ($ImportToOdsFile.IsPresent) { Import-OutputCsvToOdsFile }
	    Show-DaKrProgress -StepsCompleted $ShowProgressMaxSteps -StepsMax $ShowProgressMaxSteps -UpdateEverySeconds 1 -CurrentOper 'Finishing'
        # if (-not ($NoOutput2Screen.IsPresent)) { Write-DakrHostWithFrame -Message 'Final Result: OK' -ForegroundColor ([System.ConsoleColor]::Green) }
    }

#region TemplateEnd

if (-not($OutputDataOnly.IsPresent)) {
	Write-DakrHostHeaderV2 -ProcessedRecordsTotal $OutProcessedRecordsI
}
    Move-DakrLogFileToHistory -Path $LogFile -FileMaxSizeMB 20
	$HostRawUI.WindowTitle = $FormerPsWindowTitle
	Pop-Location
    if ($global:DebugPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue) { $global:DebugPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue }
	if ($global:TranscriptStarted) { Stop-Transcript -ErrorAction SilentlyContinue }

# http://msdn.microsoft.com/en-us/library/system.string.format.aspx
if (-not ($NoOutput2Screen.IsPresent)) { 
    if (-not($NoSound.IsPresent)) { Write-Host `a`a`a -NoNewline }
}
#endregion TemplateEnd
