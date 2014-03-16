# Start-Async for PowerShell
PowerShell multi-threading for the masses.

######Examples
```powershell
# Basic, useless example
# Cycle through each process id and get the individual process asynchronously
Start-Async { param($id); Get-Process -Id $id } -InputArray (Get-Process).id -Verbose

# Useful example
[ScriptBlock]$ScriptBlock = {
    
    Param(
        # First positional param is used with each item in Start-Async -InputArray
        $ComputerName,
        # Second and subsequent params can be provided to your ScriptBlock by Start-Async -ArgumentList
        $CustomFunctionPath,
        $SomeOtherArgumentYouNeed
    )
    
    # Source the custom function to be used in the scriptblock
    . "$CustomFunctionPath\CustomFunction.ps1"
    
    # NOTE: Modules can be imported creating an InitialSessionState object, importing the module,
    # and passing the session with Start-Async -Session
    
    $result = Invoke-Command -ComputerName $ComputerName { Get-Process -Name $SomeOtherArgumentYouNeed }
    CustomFunction $result -SomeOtherArgument $SomeOtherArgumentYouNeed
}

$CustomFunctionPath = "path\to\CustomFunction"

# Kick it off
Start-Async -ScriptBlock $ScriptBlock -InputArray $ComputerList -ArgumentList $CustomFunctionPath,$SomeOtherArgument
```

### Best practice for multi-threaded remoting
How can you manage remoting with so many threads?

I like to do the following architecture:
[init script] --> 
[kick off parallel threads] --> 
 --> [each thread remotes to separate computer to perform task]
 --> [can utilize either psexec or Invoke-Command]
      --> [perform and return remote task]
 --> [back on local computer, export results to db or file]
 --> [kick off any subsequent task related to this thread]
 --> [each thread will stop and be removed from runspace by Start-Async]

### Work-in-Progress
```Start-Async -PostScriptBlock -PostSession```
This could be used to execute a secondary scriptblock after the first, but I'm not convinced there
is a use-case for this.  The params are currently implemented but are untested.

Currently, you cannot pass [switch] params through the ArgumentList.  As a workaround, just pass
a string param and validate with an if/then block inside the ScriptBlock

### Disclaimer
Ok, so I know PowerShell multi-threading is not a simple undertaking as of now, but I needed a 
script I could pass custom arguments in order to load custom functions for mass collection.  The 
current default throttle limit is set to an arbitrary 32, but there's hardly any CPU or memory
utilization even at that level.  Feel free to explore the max throttle limits,
and let me know what you find.