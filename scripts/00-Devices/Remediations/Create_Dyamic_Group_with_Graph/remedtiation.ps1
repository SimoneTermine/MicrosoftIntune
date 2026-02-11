#Graph authentication
$clientID = "<ClientID>"
$secret = "<Secret>"
$tenantID = "<TenantID>"

#Assemble the token
$tokenUrl = "https://login.microsoftonline.com/$tenantID/oauth2/v2.0/token"

$tokenBody = @{
    client_id       = $clientID
    scope           = "https://graph.microsoft.com/.default"
    client_secret   = $secret
    grant_type      = "client_credentials"
}

$tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $tokenBody -ContentType "application/x-www-form-urlencoded"
$accessToken = $tokenResponse.access_token

$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type" = "application/json"
}

#Get Entra Device ID
$entraDeviceId = ((Get-ChildItem "Cert:\LocalMachine\My" | Where-Object {$_.Issuer -match "MS-Organization-Access"} | Select-Object Subject).Subject).TrimStart("CN=")
$entraId = (Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/beta/devices?`$filter=deviceid eq '$entraDeviceId'" -Headers $headers).value.id

$body = @"
{
    "extensionAttributes":{
        "extensionAttribute1":"HasChrome"
    }
}
"@

#Make PATCH request
Invoke-RestMethod -Method Patch -Uri "https://graph.microsoft.com/beta/devices/$($entraId)" -Headers $headers -Body $body

Write-Output "extensionAttribute1 set to Chrome for $($entraId)"








