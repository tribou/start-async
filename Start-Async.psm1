[CmdletBinding()]
Param()

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$lib = "$here\lib"

# Source functions
. "$lib\Start-Async.ps1"

# Export functions
Export-ModuleMember Start-Async
