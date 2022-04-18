Import-Module (Join-Path $PSScriptRoot "MultithreadQueue.ps1")

[Array]$ItemsToProcess = @(
    <#

    # list of items to process here

    #>
)

# alternatively
<#
$ItemsToProcess = New-Object System.Collections.ArrayList

$ItemsToProcess.AddRange(@(

    # list of items to process here

))
#>

# cross-thread output logger
$LogText = [ScriptBlock]{
    param(
        [string]$str,
        [string]$color
    )

    if ($color.Length -gt 0) {
        if ($color -eq "Orange") {
            $color = "Yellow"
        }

        Write-Host $str -ForegroundColor $color
    } else {
        Write-Host $str
    }
}

# cross-thread shared variables via synchronized hashtable
$Sync = [HashTable]::Synchronized(@{
    Total = $ItemsToProcess.Count
    Completed = 0
    LogText = $LogText
})

# instantiate queue
# $queue = New-Object MultithreadQueue($NumThreads, $RunspaceSessionVariables)
$queue = New-Object MultithreadQueue(-1, @{
    MyPSPath = $PSScriptRoot
    Sync = $Sync
})

foreach ($item in $ItemsToProcess) {
    # pause adding items to queue until next thread becomes available
    $queue.AwaitNextAvailable()

    # add job processing block with parameters
    $queue.AddJob({
        param(
            [object]$item
        )

        # Example usage:
        #[string]$Uri = "https://duckduckgo.com/assets/logo_homepage.alt.v108.svg"
        #[string]$FileSavePath = Join-Path $env:USERPROFILE ([IO.Path]::GetFilename($Uri))
        #[string]$UserAgent = [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
        #Start-ItemDownload -Uri $Uri -FileSavePath $FileSavePath -UserAgent $UserAgent
        function Start-ItemDownload {
            param(
                [Parameter(Mandatory=$true)]
                [string]$Uri,
                [Parameter(Mandatory=$true)]
                [string]$FileSavePath,
                [string]$UserAgent
            )

            if ($null -eq $UserAgent) {
                $UserAgent = [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
            }

            if ($PSVersionTable.PSVersion.Major -eq 5) {
                Set-Content -LiteralPath $FileSavePath -Value (Invoke-WebRequest -Uri $Uri -UserAgent $UserAgent).Content -Encoding Byte
            } elseif ($PSVersionTable.PSVersion.Major -eq 7) {
                Set-Content -LiteralPath $FileSavePath -Value (Invoke-WebRequest -Uri $Uri -UserAgent $UserAgent).Content -AsByteStream
            } else {
                throw "Start-ItemDownload seems not to be compatible with your version of PowerShell. Try versions 5 or 7."
            }
        }


        try {
            <#

            # job processing code here

            #>
            $Sync.Completed++
            [string]$PercentComplete = "$($Sync.Completed) of $($Sync.Total) :: $([math]::Round(100 * $Sync.Completed / $Sync.Total, 2))%"
            $Sync.LogText.Invoke("Job '$($item.ToString())' processed successfully, $PercentComplete", "Green")
        } catch {
            $Sync.Completed++
            $Sync.LogText.Invoke("An error occurred while attempting to process '$param1' ($($Sync.Completed) of $($Sync.Total))", "Red")
        }
    }, @($item))
}

# wait for jobs to finish
$queue.AwaitJobs()

# destroy the queue object
$queue.Close()

Remove-Module "MultithreadQueue"
