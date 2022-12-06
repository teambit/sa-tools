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
# - PowerShell version 5.1 or above is required.
# - The script will delete the workspace folder if it exists before running the test.
# - The script will install the requested version of Bit using bvm.
# - The script will run the commands in the order they are defined in the $commands array.
# - The script will output the time it took to run each command.
# - The script will NOT delete the workspace folder after the test is done. This is to allow you to inspect the workspace after the test is done.

param($bitVersion)
$workspaceName = "__TEMP__bit-perf-test-workspace"

Write-Host "Cleaning up"
Remove-Item $workspaceName -Force -Recurse -ErrorAction Continue
Write-Host "Done"

Write-Host "Configuring requested version of bit v $bitVersion"
bvm install $bitVersion
bvm use $bitVersion
Write-Host "Done."


$runTimes = [ordered]@{} # The results will be stored here
# The commands to run
$commands = @(
    "bit new react $workspaceName && Set-Location $workspaceName",
    # "bit import teambit.react/react --skip-dependency-installation",
    "bit install",
    "bit create react hello-world",
    "bit compile",
    "bit test"
    "bit build",
    "bit install && Set-Location .."
)

Write-Host "Running commands"

# Run the commands and measure the time it took to run each one
$seq = 1 # Used to number the commands in the output
foreach ($command in $commands) {
    $startedAt = Get-Date
    Invoke-Expression "$command"
    $runTimes["$seq. $command"] = New-TimeSpan -Start $startedAt -End (Get-Date)
    $seq = $seq + 1
}

'--------------------------------------------'
"Test results for Bit version ($bitVersion):"
$runTimes