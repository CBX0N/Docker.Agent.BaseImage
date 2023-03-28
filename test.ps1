try {
    $path = 'C:\Program Files\WindowsPowershell\Modules'
    if ((Test-Path -path (Join-Path -Path $path -ChildPath "CBXON.Deployment.Utilities") ) `
    -And (Test-Path -path (Join-Path -Path $path -ChildPath "PowershellGet\2.2.5") ) `
    -And (Test-Path -path (Join-Path -Path $path -ChildPath "dbatools")  )
    ){
        Write-Output "All Modules Present"
        Exit 0
    }
    else {
        Write-Error "All Modules Are NOT Present"
    }

}
catch {
    Write-Output "All Modules Are NOT Present"
    Exit 1
}

