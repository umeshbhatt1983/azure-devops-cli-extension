param([Boolean]$outputTestResultAsJunit=$false)

$rootPath = Get-Location
$extensionDirectory = Join-Path -Path $rootPath -ChildPath "Azure-DevOps-Cli-Extensions"

Set-Location $extensionDirectory
Write-Host "installing azure dev cli extension"
pip install --upgrade .
Write-Host "done"
Write-Host "creating wheel"
python setup.py bdist_wheel
Write-Host "done"
Set-Location $rootPath

# only needed for running tests in environment with python version less that 3.3
pip install mock

$ErrorActionPreference = "Continue"
try {
    Write-Host "trying to uninstall extension of az devops extension was installed"
    $uninstallCommand = "az extension remove -n Azure-DevOps-Cli-Extensions **2>&1 | Write-Host**"
    Invoke-Expression $uninstallCommand
    Write-Host "extension was installed and it was removed"
}
catch {
    Write-Host "extension was not installed"
}

$ErrorActionPreference = "Stop"

Write-Host "installing azure dev cli extension"
$extensions = Get-ChildItem -Path $sourceDir -Filter "*.whl" -Recurse | Select-Object FullName
az extension add --source $extensions[0].FullName -y
Write-Host "done"

az -h
az devops -h

$testFailureFound = $false

if($outputTestResultAsJunit -eq $true)
{
    pytest $testFile --junitxml "TEST-results.xml"
}
else{
    pytest $testFile
}

if ($LastExitCode -ne 0) {
    $testFailureFound = $true
}

$testFiles = @()
$testDirectory = Join-Path -Path $rootPath -ChildPath "tests"
$testFiles = Get-ChildItem -path $testDirectory -Recurse -Depth 0 -file -filter *Test.py | Select -ExpandProperty FullName

foreach($testFile in $testFiles){
    if($outputTestResultAsJunit -eq $true)
    {
        $leafFile = Split-Path $testFile -leaf
        $testResultFile = "TEST-" + $leafFile + ".xml"
        Write-Host "test result output at " $testResultFile
        pytest $testFile --junitxml $testResultFile
    }
    else{
        pytest $testFile
    }

    if ($LastExitCode -ne 0) {
        $testFailureFound = $true
      }
}

if($testFailureFound -eq $true){
    exit 1
}