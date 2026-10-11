# Copyright (c) 2026 Mystech, LLC
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
    Saves this PC's Autopilot hardware hash (and its corporate device identifier) as CSV files ready to import in Intune. Read-only on the PC.

.DESCRIPTION
    Run it on the PC being registered, from a USB stick, either:
      - at the first setup screen of a PC that hasn't been set up (Shift+F10 opens a command prompt), or
      - on a PC you can sign in to, in an administrator PowerShell window.

    It needs no internet connection, no download and no sign-in. It reads the hardware hash, serial number,
    manufacturer and model from Windows and writes two files next to this script (or in -OutputFolder), in the
    formats Intune's imports expect (plain ANSI text, no quotation marks):
      Autopilot-<serial number>.csv    the Autopilot registration: Intune > Devices > Windows > Enrollment >
                                       Devices > Import. The normal route.
      CorporateId-<serial number>.csv  the corporate device identifier (manufacturer, model, serial number, no
                                       header): Intune > Devices > Enrollment > Corporate device identifiers >
                                       Add > Upload CSV file. Only for a PC that can't be registered in Autopilot.

    The hash identifies the PC's hardware: delete the files from the stick once they're imported.

.PARAMETER OutputFolder
    Where to save the CSV. Default: the folder this script is in (the USB stick).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File E:\Get-AutopilotHash.ps1
#>
param([string]$OutputFolder = $PSScriptRoot)
$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw 'Run this from an administrator PowerShell window (right-click PowerShell > Run as administrator). At the first setup screen, Shift+F10 is already administrator.' }

try {
    $dev = Get-CimInstance -Namespace 'root/cimv2/mdm/dmmap' -ClassName 'MDM_DevDetail_Ext01' -Filter "InstanceID='Ext' AND ParentID='./DevDetail'"
}
catch { throw "Windows didn't return the hardware hash ($($_.Exception.Message)). This only works in full Windows 10 or 11, not in WinPE or a recovery environment." }
$hash = "$($dev.DeviceHardwareData)"
$serial = "$((Get-CimInstance -ClassName Win32_BIOS).SerialNumber)".Trim()
$board = Get-CimInstance -ClassName Win32_BaseBoard
if (-not $hash) { throw 'Windows returned an empty hardware hash. Check the PC runs full Windows 10 or 11 (not WinPE), then try again.' }
if (-not $serial) { throw "The PC reports no serial number, so Autopilot can't register it. Set it in the firmware (BIOS/UEFI) or work with the manufacturer." }

$model = Get-CimInstance -ClassName Win32_ComputerSystem
$safe = $serial -replace '[^A-Za-z0-9-]', '_'
if (-not $OutputFolder) { $OutputFolder = (Get-Location).Path }
$file = Join-Path $OutputFolder "Autopilot-$safe.csv"
# The import accepts ANSI text only, no quotation marks, these exact headers (case matters), no extra columns
[IO.File]::WriteAllLines($file, [string[]]@('Device Serial Number,Windows Product ID,Hardware Hash', "$serial,,$hash"), [Text.Encoding]::ASCII)
# Corporate identifier: manufacturer,model,serial with no header; commas would split the fields, periods are dropped
$idFile = Join-Path $OutputFolder "CorporateId-$safe.csv"
$idLine = (@("$($model.Manufacturer)".Trim(), "$($model.Model)".Trim(), $serial.Replace('.', '')) | ForEach-Object { $_ -replace ',', ' ' }) -join ','
[IO.File]::WriteAllLines($idFile, [string[]]@($idLine), [Text.Encoding]::ASCII)

Write-Host ''
Write-Host "Saved $file" -ForegroundColor Green
Write-Host "  and $idFile (only for a PC that can't be registered in Autopilot)"
Write-Host "  Serial number: $serial"
Write-Host "  Model:         $($model.Manufacturer) $($model.Model)"
if (-not "$($board.SerialNumber)".Trim()) { Write-Host '  Warning: the motherboard reports no serial number; if the import says InvalidZtdHardwareHash, the manufacturer has to fix the firmware.' -ForegroundColor Yellow }
Write-Host ''
Write-Host 'Next: Intune > Devices > Windows > Enrollment > Devices > Import, choose this file, then Sync.'
