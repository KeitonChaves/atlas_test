param(
    [string]$TargetHost = "host.docker.internal",
    [int]$Port = 4450,
    [int]$Threads = 50,
    [int]$RampUp = 10,
    [int]$Loops = 3,
    [string]$User = "admin",
    [string]$Pass = "admin"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ResultsDir = Join-Path $ScriptDir "results"
$HtmlDir = Join-Path $ResultsDir "html-report"

if (Test-Path $ResultsDir) {
    Remove-Item -Recurse -Force $ResultsDir
}
New-Item -ItemType Directory -Force -Path $HtmlDir | Out-Null

$UseLocalJmeter = Get-Command jmeter -ErrorAction SilentlyContinue

if ($UseLocalJmeter) {
    $LocalHost = if ($TargetHost -eq "host.docker.internal") { "localhost" } else { $TargetHost }
    Write-Host "Ejecutando JMeter local contra http://${LocalHost}:${Port}..." -ForegroundColor Cyan
    jmeter -n -t "$ScriptDir\atlas-stress-test.jmx" `
        -l "$ResultsDir\results.jtl" `
        -e -o "$HtmlDir" `
        "-JPROTOCOL=http" `
        "-JHOST=$LocalHost" `
        "-JPORT=$Port" `
        "-JTHREADS=$Threads" `
        "-JRAMPUP=$RampUp" `
        "-JLOOPS=$Loops" `
        "-JUSER=$User" `
        "-JPASS=$Pass"
} else {
    Write-Host "JMeter local no detectado. Ejecutando via Docker (justb4/jmeter:5.5) contra http://${TargetHost}:${Port}..." -ForegroundColor Cyan
    docker run --rm `
        --add-host=host.docker.internal:host-gateway `
        -v "${ScriptDir}:/tests" `
        justb4/jmeter:5.5 `
        -n -t /tests/atlas-stress-test.jmx `
        -l /tests/results/results.jtl `
        -e -o /tests/results/html-report `
        -JPROTOCOL=http `
        -JHOST=$TargetHost `
        -JPORT=$Port `
        -JTHREADS=$Threads `
        -JRAMPUP=$RampUp `
        -JLOOPS=$Loops `
        -JUSER=$User `
        -JPASS=$Pass
}

Write-Host "`nReporte HTML generado en: $HtmlDir\index.html" -ForegroundColor Green
