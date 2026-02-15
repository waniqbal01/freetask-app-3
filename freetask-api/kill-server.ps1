$port = 4000
$process = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique

if ($process) {
    Write-Host "Killing process with PID: $process running on port $port"
    Stop-Process -Id $process -Force
    Write-Host "Process killed successfully."
} else {
    Write-Host "No process found running on port $port."
}
