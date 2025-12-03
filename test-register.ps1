$body = @{
    role = "CLIENT"
    name = "wan03"
    email = "wan03@gmail.com"
    password = "test1234"
} | ConvertTo-Json

Write-Host "Sending payload:"
Write-Host $body
Write-Host ""

try {
    $response = Invoke-WebRequest -Uri "http://localhost:4000/auth/register" `
        -Method POST `
        -ContentType "application/json" `
        -Body $body `
        -UseBasicParsing
    
    Write-Host "Success: $($response.StatusCode)"
    Write-Host $response.Content
} catch {
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)"
    if ($_.Exception.Response) {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response Body: $responseBody"
        $reader.Close()
    }
}
