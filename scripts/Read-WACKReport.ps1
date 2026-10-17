param([Parameter(Mandatory)][string]$Report,[string]$OutputPath)
$ErrorActionPreference='Stop'
[xml]$xml=Get-Content -LiteralPath $Report -Raw
if (!$xml.REPORT) { throw 'Not a WACK REPORT document' }
$tests=@($xml.SelectNodes('/REPORT/REQUIREMENTS/REQUIREMENT/TEST') | ForEach-Object {
    $result=$_.SelectSingleNode('RESULT')
    if (!$result) { throw 'WACK test missing result' }
    [pscustomobject]@{
        Name=$_.GetAttribute('NAME')
        Optional=($_.GetAttribute('OPTIONAL') -eq 'TRUE')
        Result=$result.InnerText.Trim()
        Messages=@($_.SelectNodes('MESSAGES/MESSAGE') | ForEach-Object { $_.GetAttribute('TEXT') })
    }
})
if (!$tests.Count) { throw 'No WACK test results found' }
$summary=[pscustomobject]@{
    OverallResult=$xml.REPORT.GetAttribute('OVERALL_RESULT')
    PartialRun=($xml.REPORT.GetAttribute('PARTIAL_RUN') -eq 'TRUE')
    WackVersion=$xml.REPORT.GetAttribute('VERSION')
    OSVersion=$xml.REPORT.GetAttribute('OSVERSION')
    TestCount=$tests.Count
    Passed=@($tests | Where-Object Result -eq 'PASS').Count
    RequiredNonPass=@($tests | Where-Object { !$_.Optional -and $_.Result -ne 'PASS' })
    OptionalNonPass=@($tests | Where-Object { $_.Optional -and $_.Result -ne 'PASS' })
    Tests=$tests
}
if ($OutputPath) { $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath }
$summary
