# Not the prettiest thing in the world, but it will do for now.

# This script is used to measure the time it takes to run a series of commands on a new Bit workspace.
# It will create a new workspace, install the requested version of Bit, and run a predefiend series of commands.
# It will then output the time it took to run each command.

# Usage:
# 1. Open a PowerShell terminal
# 2. Run the script with the version of Bit you want to test as a parameter:
#    .\run-test.ps1 0.0.888
# 3. The results will be printed to the terminal

#params:
# $bitVersion - The version of Bit to test.
#               Defaults to 0.1.11
# $iterations - The number of times to run each command.
#               Defaults to 5
# $framework -  The framework to use (react or angular).
#               Defaults to react
#
# Example (all arguments have to be provided in the same order):
# .\run-test.ps1 0.0.888 5 react
# .\run-test.ps1 0.0.888 5 angular

# or with named parameters (order of the parameters does not matter):
# .\run-test.ps1 -bitVersion 0.0.888 -iterations 5 -framework react
# .\run-test.ps1 -bitVersion 0.0.888 -iterations 5 -framework angular


param(
    [string]$bitVersion = "0.1.11",
    [int]$iterations = 5,
    [string]$framework = "react"
)

$script:stats = New-Object System.Data.DataTable # Used to ccollect run statistics
function getDeletedWorkspaceName() {
    return "ws-$framework-$([guid]::NewGuid())"
}

function getCsvFileName() {
    return $script:csvFileName
}

function getLogFileName() {
    return $script:logFileName
}

# The commands to run for react
function getReactCommands() {
    return @(
        "bit new react ${script:workspaceName} --aspect teambit.react/react-env --default-scope test-org.test-scope",
        "cd ./${script:workspaceName}",
        "bit install",
        "bit compile",
        "bit status",
        "bit create react my-button",
        "bit create react my-button2",
        "bit create react my-button3",
        "bit install", # BUG: will not work without this install
        "bit compile",
        "bit status",
        "bit install",
        "bit lint",
        "bit test",
        "bit build",
        "bit tag",
        "bit remove my-button -s",
        "bit -h",
        "cd .."
    )
}

# The commands to run for angular
function getAngularCommands() {
    return @(    
        # "bit new angular ${script:workspaceName} --env teambit.angular/angular --default-scope test-org.test-scope",
        "bit new angular ${script:workspaceName}  --aspect teambit.angular/angular --default-scope test-org.test-scope",
        "cd ./${script:workspaceName}",
        "bit install",
        "bit compile",
        "bit create angular my-button",
        "bit create angular my-button2",
        "bit create angular my-button3",
        "bit compile",
        "bit status",
        "bit install",
        "bit lint",
        "bit test",
        "bit build",
        "bit tag",
        "bit remove org.scope-name/my-button -s",
        "bit -h",
        "cd .."
    )
}

# The commands to run
# The commands are defined as a function so that we can return different commands for different frameworks
function getCommands() {
    if ($framework -eq "react") {
        return getReactCommands
    }
    if ($framework -eq "angular") {
        return getAngularCommands
    }
}

function initStatsTable() {
    $script:stats.Columns.Add("Id")
    $script:stats.Columns.Add("Framework")
    $script:stats.Columns.Add("Version")
    $script:stats.Columns.Add("Device")
    $script:stats.Columns.Add("Command")
    for ($i = 0; $i -lt $iterations; $i++) {
        $script:stats.Columns.Add("Seq_$($i+1) seconds")
    }

    $i = 1
    foreach ($command in $script:commands) {
        $script:stats.Rows.Add($i, $framework, $bitVersion, "", $command)
        $i = $i + 1
    }

    $script:stats | Format-Table -AutoSize
}

function writeLog([string]$message) {
    # writeLog $messageconst 
    $timeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)

    Write-OutPut "$timeStamp $message" | Out-File -Append -FilePath $(getLogFileName)
    Write-Host $message
}
function report() {
    writeLog 'Stats:.'

    $script:stats | Format-Table -AutoSize
    $script:stats | export-csv $(getCsvFileName) -notypeinformation

    writeLog $script:stats
    writeLog 'Done with Stats.'
}

function setup() {
    if (!(Test-Path "./$script:deleted")) {
        writeLog "Creating deleted folder"
        New-Item $script:deleted -ItemType Directory -Force
    }

    # Remove the BIT_FEATURES env variable if it exists to force local toolchain execution
    Remove-Item Env:\BIT_FEATURES

    writeLog "Initializing stats table"
    initStatsTable
    
    writeLog "Configuring requested version of bit $bitVersion"
    npx bvm install $bitVersion
    npx bvm use $bitVersion
    writeLog "Done."
}

function cleanUp() {
    If (Test-Path "./${script:workspaceName}") {
        writeLog pwd
        writeLog "Deleting workspace folder"
        Move-Item "./${script:workspaceName}" "./$deleted/$([guid]::NewGuid())" 
    }
    writeLog "Done"
}

function run([int]$sequence) {
    $id = 1 # Used to number the commands in the output
    foreach ($command in $script:commands) {
        writeLog "Running $command"
        $startedAt = Get-Date
        Invoke-Expression $command
        $endedAt = Get-Date
        $elapsed = New-TimeSpan -Start $startedAt -End $endedAt
        
        $script:stats | Where-Object { $_.Id -eq $id } | ForEach-Object { $_["Seq_$sequence seconds"] = $elapsed.TotalMilliseconds / 1000 }
        report
        $id = $id + 1
    }
}


$script:workspaceName = "test-workspace"
$script:baseDir = $(Get-Location)
$script:scriptStartedAt = Get-Date -Format 'yyyy-MM-dd_hh.mm.ss.fff'
$script:csvFileName = "${script:baseDir}/${script:scriptStartedAt}.csv"
$script:logFileName = "${script:baseDir}/${script:scriptStartedAt}.log"
$script:deleted = "./deleted"
$script:commands = getCommands

setup
for ($i = 0; $i -lt $iterations; $i++) {
    run($i + 1)
    cleanUp
}
report
cleanUp