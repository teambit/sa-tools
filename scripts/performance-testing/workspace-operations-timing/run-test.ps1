# Not the prettiest thing in the world, but it will do for now.

# This script is used to measure the time it takes to run a series of commands on a new Bit workspace.
# It will create a new workspace, install the requested version of Bit, and run a predefiend series of commands.
# It will then output the time it took to run each command.

# Usage:
# 1. Open a PowerShell terminal
# 2. Run the script with the version of Bit you want to test as a parameter:
#    .\run-test.ps1 0.0.888
# 3. The results will be printed to the terminal

# Notes: 
# - PowerShell version 7.0.0 or above is required.
# - The script will delete the workspace folder if it exists before running the test.
# - The script will install the requested version of Bit using bvm.
# - The script will run the commands in the order they are defined in the $commands array.
# - The script will output the time it took to run each command.
# - The script will NOT delete the workspace folder after the test is done. This is to allow you to inspect the workspace after the test is done.

# Inline If function
# Usage:
# IIf($condition, $ifTrue, $ifFalse)
# IIf($condition, { $ifTrue }, { $ifFalse })
param(
    [string]$bitVersion = "latest",
    [int]$iterations = 1,
    [string]$workspaceName = "__TEMP__bit-perf-test-workspace",
    [string]$out = "stats-$bitVersion-$(Get-Date -Format 'yyy-ymm-dd.hh.mm.ss.fff').csv"
)

$commands = @(
    "bit new react $workspaceName && Set-Location $workspaceName",
    "bit install",
    "bit create react hello-world",
    "bit compile",
    "bit test"
    "bit build",
    "bit install && Set-Location .."

)

$stats = New-Object System.Data.DataTable # Used to ccollect run statistics
$stats.Columns.Add("Id")
$stats.Columns.Add("Operation")
for ($i = 0; $i -lt $iterations; $i++) {
    $stats.Columns.Add("Seq_$($i+1)")
}

$i = 1
foreach ($command in $commands) {
    $stats.Rows.Add($i, $command)
    $i = $i + 1
}

function setup() {
    Write-Host "Configuring requested version of bit $bitVersion"
    bvm install $bitVersion
    bvm use $bitVersion
    Write-Host "Done."
}

function run([int]$sequence) {
    Write-Host "Cleaning up"
    try {
        Remove-Item $workspaceName -Force -Recurse -ErrorAction Stop
    }
    catch {
    }
    Write-Host "Done"

    Write-Host "Running commands"
    # Run the commands and measure the time it took to run each one 

    $id = 1 # Used to number the commands in the output
    foreach ($command in $commands) {
        $startedAt = Get-Date
        Invoke-Expression "$command"
        $endedAt = Get-Date
        $elapsed = New-TimeSpan -Start $startedAt -End $endedAt
        
        $stats | Where-Object { $_.Id -eq $id } | ForEach-Object { $_["Seq_$sequence"] = [math]::Round($elapsed.TotalMilliseconds, 0) }

        # $stats.Rows.Add($seq, $command, $startedAt, $endedAt, $elapsed.TotalMilliseconds)
        
        $id = $id + 1
    }
}

function report() {
    Write-Host 'Stats:.'
    $stats | Format-Table -AutoSize
    $stats | export-csv $out -notypeinformation
}


setup
for ($i = 0; $i -lt $iterations; $i++) {
    run($i + 1)
}
report


