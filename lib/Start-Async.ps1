# I have a couple sources to thank for this conglomeration that I will update shortly
# ...after I find them again
# most knowledge was gained through the TechNet articles on 
# System.Management.Automation.Runspaces

function Start-Async {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,Position=0)]
        [scriptblock]$ScriptBlock,
        [Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$true)]
        [string[]]$InputArray,
        [int]$Throttle = 32,
        [double]$SleepTimer,
        [int]$Timeout,
        [object[]]$ArgumentList,
        [scriptblock]$PostScriptBlock,
        [scriptblock[]]$Function, #TODO: verify this even works
        [System.Management.Automation.Runspaces.InitialSessionState]$Session,
        [System.Management.Automation.Runspaces.InitialSessionState]$PostSession
    )
  
    BEGIN {
    
        #Define the initial sessionstate, create the runspacepool
        $Start = Get-Date
        $RunspaceCollection = @()
        $ReturnedRunspaceCollection = @()

        if(!$Session){
            Write-Verbose "Creating default session for runspaces"
            $Session = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        } else {
            Write-Verbose "Using session passed by user to create runspaces"
        }
        if(($PostScriptBlock -ne $null) -AND !$PostSession){
            Write-Verbose "Creating default session for postscript runspaces"
            $PostSession = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        } elseif(!$PostSession -AND !$PostSession){
            #Do Nothing
        } else {
            Write-Verbose "Using postsession passed by user to create postscript runspaces"
        }

        Write-Verbose "Creating runspace pool with $Throttle threads"
        $RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $Throttle, $Session, $host)
        $RunspacePool.Open()

        if($PostScriptBlock) {
            Write-Verbose "Creating postscript runspace pool with $Throttle threads"
            $ReturnedRunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $Throttle, $Session, $host)
            $ReturnedRunspacePool.Open()
        }
  
    } PROCESS {
    
        # Create a powershell process for each item in InputArray
        foreach($item in $InputArray){
          
            #Create a PowerShell object to run add the script and argument
            Write-Verbose "Creating Powershell object for $item"
            $Powershell = [PowerShell]::Create()
          
            if($Function){
                #Adding dependent functions
                #TODO: this block is untested and may not be working
                #Alternative is to add functions in the ScriptBlock itself and pass the path to the function
                #through an argument in ArgumentList.  See the README for an example.
                foreach($script in $Function){
                    $Powershell.AddScript($script) | Out-Null
                }
            }
          
            # Add the main script
            $Powershell.AddScript($ScriptBlock).AddArgument($item) | Out-Null

            #Add additional arguments
            if($ArgumentList){
                foreach($argument in $ArgumentList){
                    $Powershell.AddArgument($argument) | Out-Null
                }
            }

            #Specify runspace to use
            $Powershell.RunspacePool = $RunspacePool

            #Create Runspace collection
            Write-Verbose "Invoking script for $item"
            [Collections.Arraylist]$RunspaceCollection += New-Object -TypeName PSObject -Property @{
                Runspace = $PowerShell.BeginInvoke()
                PowerShell = $PowerShell
                Name = $item
            }
          
        }
    
    
    } END {
    
        [int]$i = 0
        Write-Verbose "Checking for completed runspaces..."
        While($RunspaceCollection){
            Foreach($Runspace in $RunspaceCollection.ToArray()){
                If($Runspace.Runspace.IsCompleted){
                  
                    $i++
                    Write-Verbose "Removing runspace no $i - $($Runspace.Name) from queue"
                    try {

                        $Runspace.PowerShell.EndInvoke($Runspace.Runspace)
                        
                        # Check for errors
                        if($Runspace.PowerShell.HadErrors){
                            Write-Error $_ | select *
                        }

                        if($PostScriptBlock){
                        
                            $ReturnedPowershell = [PowerShell]::Create().AddScript($PostScriptBlock).AddArgument($result)

                            #Specify runspace to use
                            $ReturnedPowershell.RunspacePool = $ReturnedRunspacePool

                            #Create Runspace collection
                            [Collections.Arraylist]$ReturnedRunspaceCollection += New-Object -TypeName PSObject -Property @{
                                Runspace = $ReturnedPowerShell.BeginInvoke()
                                PowerShell = $ReturnedPowerShell
                                Name = ""
                            }
                        }

                    } catch [Exception] {

                        Write-Error "Exception called:"
                        Write-Error $_
                        $_ | Select *

                    } finally {

                        $Runspace.PowerShell.Dispose()
                        $RunspaceCollection.Remove($Runspace)
                    }
                  
                }
            }
            
            # If timeout is set, check for breach
            if($Timeout){
                if((Get-Date) -gt $Start.AddMinutes($Timeout)){
                    Write-Verbose "Timeout breached! Ending script..."
                    Write-Verbose "Clearing runspace collection"
                    $RunspaceCollection.Clear()
                }
            }
          
            #Sleep may cut down on cpu usage slightly, but not necessary in most cases
            if($SleepTimer){
                Start-Sleep -Milliseconds $SleepTimer
            }
        }
        
        
        While($ReturnedRunspaceCollection){
            Foreach($Runspace in $ReturnedRunspaceCollection.ToArray()){
                If($Runspace.Runspace.IsCompleted){
                  
                    Write-Verbose "Removing ReturnedRunspace from queue"
                    $Runspace.PowerShell.EndInvoke($Runspace.Runspace)
                    $Runspace.PowerShell.Dispose()
                    $ReturnedRunspaceCollection.Remove($Runspace)
                }
            }
          
            if($Timeout){
                if((Get-Date) -gt $Start.AddMinutes($Timeout)){
                    Write-Verbose "Timeout breached! Ending script..."
                    $ReturnedRunspaceCollection.Clear()
                }
            }
        }
      
        
        Write-Verbose "Closing runspace pool"
        $RunspacePool.Close()
        if($PostScriptBlock){
            $ReturnedRunspacePool.Close()
        }
        $TimeSpan = New-TimeSpan -Start $Start -End (Get-Date)
     
        Write-Verbose "Script elapsed time : $($TimeSpan.Hours) hours $($TimeSpan.Minutes) minutes $($TimeSpan.Seconds) seconds and $($TimeSpan.Milliseconds) Milliseconds"
        
    }
}