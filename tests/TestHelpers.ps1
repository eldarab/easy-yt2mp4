# A tiny test runner, so the tests need nothing beyond Windows PowerShell 5.1.
$script:TestFailures = 0
$script:TestPasses = 0
$script:TestGroup = ''

function Describe {
    param([string]$Name, [scriptblock]$Body)
    $script:TestGroup = $Name
    Write-Host $Name
    try { & $Body } catch {
        $script:TestFailures++
        Write-Host "  FAIL (threw): $_" -ForegroundColor Red
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Because = '')
    if ($Expected -is [string] -and $Actual -is [string]) { $same = [string]::Equals($Expected, $Actual, [StringComparison]::Ordinal) }
    else { $same = ($Expected -eq $Actual) -and (($null -eq $Expected) -eq ($null -eq $Actual)) }
    if ($same) { $script:TestPasses++; return }
    $script:TestFailures++
    Write-Host ("  FAIL {0}`n       expected: [{1}]`n       actual:   [{2}]" -f $Because, $Expected, $Actual) -ForegroundColor Red
}

function Assert-True {
    param([bool]$Condition, [string]$Because = '')
    if ($Condition) { $script:TestPasses++; return }
    $script:TestFailures++
    Write-Host "  FAIL $Because" -ForegroundColor Red
}

function New-TestFolder {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ('easyyt-test-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    return $dir
}

function Complete-Tests {
    Write-Host ''
    if ($script:TestFailures -gt 0) {
        Write-Host "$($script:TestFailures) failed, $($script:TestPasses) passed" -ForegroundColor Red
        exit 1
    }
    Write-Host "All $($script:TestPasses) checks passed" -ForegroundColor Green
    exit 0
}
