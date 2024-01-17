
<#-----------------------------------------------------------------------------
Author: Alexander Zagranichnov

.SYNOPSIS
    This script parses the MPRegistry.txt file and displays the most critical Defender AV settings in a summary table, as well as the ASR rules state.

.DESCRIPTION
    This script parses the MPRegistry.txt file and displays the most critical Defender AV settings in a summary table, as well as the ASR rules state.

    How to obtain MPResgisty.txt and use the script:

    1. Run CMD as administrator.
    2. Generate support package using: "%ProgramFiles%\Windows Defender\MpCmdRun.exe" -getfiles -supportloglocation c:\temp\.
    3. Expand generated MpSupportFiles.cab archive and copy the MPRegistry.txt file from the support package to a local folder.
    4. Right-click script, select 'Run with Powerhell'
    5. In the upper-left corner specify full path to MPRegistry.txt file extracted from the support package.
    6. Click "Parse" button to parse the file and display the results in the table.
    7. Use 'Export' buttons to export parsed data when necessary.

    Note: best experience while ran through Powershell.exe, not ISE/VSCode and etc. Due to DPI issues.


THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE
-----------------------------------------------------------------------------#>


#========================================[Variables]==========================================

$scriptDir = Split-Path -parent $MyInvocation.MyCommand.Path
$helpMessage = @"
This script parses the MPRegistry.txt file and displays the most critical Defender AV settings in a summary table, as well as the ASR rules state.

How to obtain MPResgisty.txt and use the script:

1. Run CMD as administrator.
2. Generate support package using: "%ProgramFiles%\Windows Defender\MpCmdRun.exe" -getfiles -supportloglocation c:\temp\.
3. Expand generated MpSupportFiles.cab archive and copy the MPRegistry.txt file from the support package to a local folder.
4. Right-click script, select 'Run with Powerhell'
5. In the upper-left corner specify full path to MPRegistry.txt file extracted from the support package.
6. Click "Parse" button to parse the file and display the results in the table.
7. Use 'Export' buttons to export parsed data when necessary.

Note: best experience while ran through Powershell.exe, not ISE/VSCode and etc. Due to DPI issues.

"@



#========================================[Initialisations]==================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public class ProcessDPI {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetProcessDPIAware();      
}
'@
$null = [ProcessDPI]::SetProcessDPIAware()

# Create a new form
$form = New-Object System.Windows.Forms.Form
$form.SuspendLayout()
$form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
$form.ClientSize = '1000,800'
$form.Text = "MPRegistry Parser"

# Create a button
$parseButton = New-Object System.Windows.Forms.Button
$parseButton.Location = New-Object System.Drawing.Point(190, 20)
$parseButton.Size = New-Object System.Drawing.Size(50, 20)
$parseButton.Font = 'Microsoft Sans Serif,10'
$parseButton.Text = "Parse"

# Create a button
$exportButton = New-Object System.Windows.Forms.Button
$exportButton.Location = New-Object System.Drawing.Point(250, 20)
$exportButton.Size = New-Object System.Drawing.Size(90, 20)
$exportButton.Font = 'Microsoft Sans Serif,10'
$exportButton.Text = "Export TXT"

# Export button
$exportJsonButton = New-Object System.Windows.Forms.Button
$exportJsonButton.Location = New-Object System.Drawing.Point(340, 20)
$exportJsonButton.Size = New-Object System.Drawing.Size(90, 20)
$exportJsonButton.Font = 'Microsoft Sans Serif,10'
$exportJsonButton.Text = "Export JSON"

# HELP button
$helpButton = New-Object System.Windows.Forms.Button
$helpButton.Location = New-Object System.Drawing.Point(450, 20)
$helpButton.Size = New-Object System.Drawing.Size(75, 20)
$helpButton.Font = 'Microsoft Sans Serif,10'
$helpButton.Text = "Help"


# Create a text box
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(20, 20)
$textBox.Size = New-Object System.Drawing.Size(150, 50)
$textBox.Font = 'Microsoft Sans Serif,10'
$textBox.Text = "C:\temp\MPRegistry.txt"

# Create a title
$labelConflictResolution = New-Object System.Windows.Forms.Label
$labelConflictResolution.Location = New-Object System.Drawing.Point(540, 20)
$labelConflictResolution.Size = New-Object System.Drawing.Size(650, 20)
$labelConflictResolution.Font = 'Microsoft Sans Serif,10'
$labelConflictResolution.Text = "*Policy Conflict Resolution: GPO > Local GPO > MDM > Powershell > WMI"

# Create a Listiew
$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(20, 60)
$listView.Size = New-Object System.Drawing.Size(950, 350)
$listView.View = 'Details'
$listView.Font = 'Microsoft Sans Serif,10'
$listView.Columns.Add('setting',250) | Out-Null


# Create a title ASR
$labelAsr = New-Object System.Windows.Forms.Label
$labelAsr.Location = New-Object System.Drawing.Point(20, 430)
$labelAsr.Size = New-Object System.Drawing.Size(300, 20)
$labelAsr.Font = 'Microsoft Sans Serif,10'
$labelAsr.Text = "ASR Rules Effective State"


# Create a ListiewAsr
$listViewAsr = New-Object System.Windows.Forms.ListView
$listViewAsr.Location = New-Object System.Drawing.Point(20, 450)
$listViewAsr.Size = New-Object System.Drawing.Size(950, 300)
$listViewAsr.View = 'Details'
$listViewAsr.Font = 'Microsoft Sans Serif,10'
$listViewAsr.Columns.Add('ruleId',250) | Out-Null
$listViewAsr.Columns.Add('state',150) | Out-Null
$listViewAsr.Columns.Add('description',500) | Out-Null



#========================================[Functions]========================================

# function to parse the MPRegistry.txt file into a hashtable with all the settings grouped by configuration set/source: effective policy, system policy, preferences, mdm policy
function ParseMPRegistry {
    param (
        $filepath
    )

$content = Get-Content $filePath
$sections = @{}
$data = @{}

foreach ($_ in $content) {
    $line = $_.Trim()

    if ($line -match "^Windows Setup keys from") {
        break
    }
    elseif ($line -match "^(Current configuration options for location) ""([^""]+)""$") {
        $config = $matches[2]
        if ($data.Count -ne 0) {
                $sections += $data
                $data = @{}    
            }
    }
    elseif ($line -match "^\[.*\]$") {
        $sectionPath = $line.TrimStart("[").TrimEnd("]").Split("\")
        $sectionPath = ,$config + $sectionPath
        $currentData = $data
        foreach ($section in $sectionPath) {
            if ($section -eq ".") {
                $currentData = $currentData
            }
            else {
                if (-not $currentData.ContainsKey($section)) {
                    $currentData[$section] = @{}
                }
                $currentData = $currentData[$section]
            }
        }
    }
    elseif ($line -match "^\s*([A-Fa-f0-9-]+|\w+)\s+\[REG_(\w+)\]\s+:\s*(.*)$") {

        $property = $matches[1]
        $type = $matches[2]
        $value = $matches[3]

        $currentData[$property] = @{
            "Type" = $type
            "Value" = $value
        }
    }
}

if ($data.Count -ne 0) {
    $sections += $data
}
return $sections
}



# function to hand select some of the most critical settings, can be expanded if needed
function SelectedSettings {
    param (
        $Sections,
        $ConfigSet
    )
$selected = New-Object System.Collections.Specialized.OrderedDictionary
$selected = @{
    DisableAntiSpyware = $sections[$ConfigSet].DisableAntiSpyware.Value;
    DisableAntiVirus = $sections[$ConfigSet].DisableAntiVirus.Value;
    DisableBehaviorMonitoring = $sections[$ConfigSet]."Real-Time Protection".DisableBehaviorMonitoring.Value;
    DisableRealtimeMonitoring = $sections[$ConfigSet]."Real-Time Protection".DisableRealtimeMonitoring.Value;
    DisableIOAVProtection = $sections[$ConfigSet]."Real-Time Protection".DisableIOAVProtection.Value;
    SpyNetReporting = $sections[$ConfigSet].Spynet.SpynetReporting.Value;
    MpCloudBlockLevel = $sections[$ConfigSet].MpEngine.MpCloudBlockLevel.Value;
    DisableBlockAtFirstSeen = $sections[$ConfigSet].Spynet.DisableBlockAtFirstSeen.Value;
    MpBafsExtendedTimeout = $sections[$ConfigSet].MpEngine.MpBafsExtendedTimeout.Value;
    EnableNetworkProtection = $sections[$ConfigSet]."Windows Defender Exploit Guard"."Network Protection".EnableNetworkProtection.Value;
    AllowNetworkProtectionOnWinServer = $sections[$ConfigSet]."Windows Defender Exploit Guard"."Network Protection".AllowNetworkProtectionOnWinServer.Value;
    AllowNetworkProtectionDownLevel = $sections[$ConfigSet]."Windows Defender Exploit Guard"."Network Protection".AllowNetworkProtectionDownLevel.Value;
    AllowDatagramProcessingOnWinServer = $sections[$ConfigSet].NIS.Consumers.IPS.AllowDatagramProcessingOnWinServer.Value;
    PUAProtection = $sections[$ConfigSet].PUAProtection.Value;
    AVSignatureVersion = $sections[$ConfigSet]."Signature Updates".AVSignatureVersion.Value;
    EngineVersion = $sections[$ConfigSet]."Signature Updates".EngineVersion.Value;
    FallbackOrder = $sections[$ConfigSet]."Signature Updates".FallbackOrder.Value;
    SignaturesLastUpdated = $sections[$ConfigSet]."Signature Updates".SignaturesLastUpdated.Value;
}
return $selected
}

# function takes selected settings above and compares them between configuration sets
function ParseAVSettings {
    param (
        $filepath
    )
    $listView.Items.Clear()
    $ConfigSets = ParseMPRegistry -filepath $filepath
    $subset = SelectedSettings -ConfigSet "effective policy" -sections $ConfigSets


    foreach ($setting in ($subset.Keys | Sort-Object)) {
        $item = New-Object System.Windows.Forms.ListViewItem($setting)
        foreach ($ConfigSet in ($ConfigSets.Keys | Sort-Object)) {
            $subset = SelectedSettings -ConfigSet $ConfigSet -sections $ConfigSets

            if (!($listView.Columns.Text -contains $ConfigSet)) {
                $listView.Columns.Add($ConfigSet,200)
            }
            
            if ($subset.$setting -eq $null) {
                $subset.$setting = "<not set>"
                $item.SubItems.Add($subset.$setting)
            }
            elseif ($setting -in ("DisableRealtimeMonitoring", "DisableAntiSpyware", "DisableAntiVirus", "DisableBehaviorMonitoring") -and $subset.$setting -eq "1 (0X1)" -and $ConfigSet -eq "effective policy") {
                
                $subItem = $item.SubItems[$item.SubItems.Count - 1]
                $subItem.ForeColor = "Red"  # Change the color to red
                $item.SubItems.Add($subset.$setting)
            }
            else {
                $item.SubItems.Add($subset.$setting)
            }
        }
        $listView.Items.Add($item)
    }
}


# function parses ASR rules state in "effective policy"
function ParseAsrRules {
    param (
        $filepath
    )

    $listViewAsr.Items.Clear()
    $ConfigSets = ParseMPRegistry -filepath $filepath
    $asrRulesState = $ConfigSets."effective policy"."Windows Defender Exploit Guard".ASR.Rules
    
    $asrRulesReference = @{
        "56a863a9-875e-4185-98a7-b882c64b5ce5" = "Block abuse of exploited vulnerable signed drivers"
        "7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c" = "Block Adobe Reader from creating child processes"
        "d4f940ab-401b-4efc-aadc-ad5f3c50688a" = "Block all Office applications from creating child processes"
        "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2" = "Block credential stealing from the Windows local security authority subsystem (lsass.exe)"
        "be9ba2d9-53ea-4cdc-84e5-9b1eeee46550" = "Block executable content from email client and webmail"
        "01443614-cd74-433a-b99e-2ecdc07bfc25" = "Block executable files from running unless they meet a prevalence, age, or trusted list criterion"
        "5beb7efe-fd9a-4556-801d-275e5ffc04cc" = "Block execution of potentially obfuscated scripts"
        "d3e037e1-3eb8-44c8-a917-57927947596d" = "Block JavaScript or VBScript from launching downloaded executable content"
        "3b576869-a4ec-4529-8536-b80a7769e899" = "Block Office applications from creating executable content"
        "75668c1f-73b5-4cf0-bb93-3ecf5cb7cc84" = "Block Office applications from injecting code into other processes"
        "26190899-1602-49e8-8b27-eb1d0a1ce869" = "Block Office communication application from creating child processes"
        "e6db77e5-3df2-4cf1-b95a-636979351e5b" = "Block persistence through WMI event subscription"
        "d1e49aac-8f56-4280-b9ba-993a6d77406c" = "Block process creations originating from PSExec and WMI commands"
        "b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4" = "Block untrusted and unsigned processes that run from USB"
        "a8f5898e-1dc8-49a9-9878-85004b8a61e6" = "Block Webshell creation for Servers"
        "92e97fa1-2edf-4476-bdd6-9dd0b4dddc7b" = "Block Win32 API calls from Office macros"
        "c1db55ab-c21a-4637-bb3f-a12568109d35" = "Use advanced protection against ransomware"
    }

# format state values to human readable

foreach ($rule in $asrRulesState.Values) {
    if ($rule.Value -eq "1 (0X1)") {
        $rule.Value = "Enabled"
    }
    elseif ($rule.Value -eq "0 (0X0)") {
        $rule.Value = "Disabled"
    }
    elseif ($rule.Value -eq "2 (0X2)") {
        $rule.Value = "Audit mode"
    }
    elseif ($rule.Value -eq "6 (0X6)") {
        $rule.Value = "Warning"
    }
    else {
        $rule.Value = "Not configured"
    }
}

# add description to ASR Rules
$mergedAsrRules = @{}
foreach ($ruleId in $asrRulesReference.Keys) {
    if ($asrRulesState.ContainsKey($ruleId)) {
        $mergedAsrRules[$ruleId] = [PSCustomObject]@{
            Description = $asrRulesReference[$ruleId]
            State = $asrRulesState[$ruleId].Value
        }
    }
    else {
        $mergedAsrRules[$ruleId] = [PSCustomObject]@{
            Description = $asrRulesReference[$ruleId]
            State = "Not configured"
        }
    }
}

# Populate ListView table with ASR rules

foreach ($rule in $mergedAsrRules.Keys) {
    $item = New-Object System.Windows.Forms.ListViewItem($rule)
    $item.SubItems.Add($mergedAsrRules.$rule.State)
    $item.SubItems.Add($mergedAsrRules.$rule.Description)
    $listViewAsr.Items.Add($item)
}
return $mergedAsrRules
}

#========================================[Buttons]==============================================

$exportButton.Add_Click({

    $filepath = $textBox.Text
    $comparisonTable = @()

    $ConfigSets = ParseMPRegistry -filepath $filepath
    $subset = SelectedSettings -ConfigSet "effective policy" -sections $ConfigSets
    $mergedAsrRules = ParseAsrRules $filepath
    
    foreach ($setting in ($subset.Keys | Sort-Object)) {
        $line = [PSCustomObject]@{"Setting" = $setting}
        foreach ($ConfigSet in $ConfigSets.Keys) {
            $subset = SelectedSettings -ConfigSet $ConfigSet -sections $ConfigSets
            $line | Add-Member -MemberType NoteProperty -Name $ConfigSet -Value $subset.$setting
            if ($subset.$setting -eq $null) {
                $subset.$setting = "<not set>"
            }
            
        }
        $comparisonTable += $line
    }
    $comparisonTable | Format-Table | out-file $scriptDir"\mpresgistry_export.txt"
    

    $asrRulesTable = @()

    foreach ($rule in $mergedAsrRules.Keys) {
        $ruleId = $rule
        $state = $mergedAsrRules.$rule.State
        $description = $mergedAsrRules.$rule.Description
        $line = [PSCustomObject]@{"RuleId" = $ruleId; "State" = $state; "Description" = $description}
        $asrRulesTable += $line
    }
    $asrRulesTable | Format-Table | out-file $scriptDir"\mpresgistry_export.txt" -Append

    notepad.exe $scriptDir"\mpresgistry_export.txt"
})




$parseButton.Add_Click({
    $filepath = $textBox.Text
    
    ParseAVSettings -filepath $filepath

    ParseAsrRules $filepath

})



# export all settings from MPRegistry.txt to JSON

$ExportJsonButton.Add_Click({

    $filepath = $textBox.Text
    $ConfigSets = ParseMPRegistry -filepath $filepath
    $ConfigSets | ConvertTo-Json -Depth 100 | Out-File $scriptDir"\MPRegistry.json"
    notepad.exe $scriptDir"\MPRegistry.json"

})



# Generate help message

$helpButton.Add_Click({
    [System.Windows.Forms.MessageBox]::Show($helpMessage, "Help")
})



#========================================[Forms]==============================================


# Add items to the form

$form.Controls.Add($parseButton)
$form.Controls.Add($exportButton)
$form.Controls.Add($textBox)
$form.Controls.Add($listView)
$form.Controls.Add($listViewAsr)
$form.Controls.Add($labelAsr)
$form.Controls.Add($labelConflictResolution)
$form.Controls.Add($exportJsonButton)
$form.Controls.Add($helpButton)

# Show the form
#$form.ShowDialog()

$form.ResumeLayout()
[void]$form.ShowDialog()


