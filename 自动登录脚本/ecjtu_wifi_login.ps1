param(
    [switch]$Auto,
    [switch]$Logout,
    [switch]$Status,
    [switch]$KeepAlive,
    [string]$Username,
    [string]$Password,
    [string]$Carrier = "cmcc",
    [int]$KeepAliveInterval = 120,
    [int]$RetryCount = 5,
    [int]$RetryDelay = 10
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$AUTH_HOST   = "172.16.2.100"
$AUTH_PORT   = 801
$LOGIN_URL   = "http://${AUTH_HOST}:${AUTH_PORT}/eportal/?c=ACSetting&a=Login"
$LOGOUT_URL  = "http://${AUTH_HOST}/eportal/?c=ACSetting&a=Logout&ver=1.0"
$QUERY_URL   = "http://${AUTH_HOST}/eportal/?c=ACSetting&a=Query"
$CONFIG_FILE = "$PSScriptRoot\ecjtu_wifi_config.json"
$LOG_FILE    = "$PSScriptRoot\ecjtu_wifi_log.txt"
$WIFI_SSID   = "ECJTU-Stu"

$CARRIERS = @{ "xyw"="@xyw"; "dx"="@dx"; "lt"="@lt"; "cmcc"="@cmcc"; ""="" }

function Write-Log {
    param([string]$Msg, [string]$Lv = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $e = "[$ts] [$Lv] $Msg"
    $c = switch ($Lv) { "ERROR" {"Red"} "WARN" {"Yellow"} "OK" {"Green"} default {"White"} }
    Write-Host $e -ForegroundColor $c
    try { Add-Content -Path $LOG_FILE -Value $e -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
}

function Save-Credential {
    param([string]$U, [string]$P)
    @{ Username=$U; Password=$P; Carrier=$Carrier; SavedAt=(Get-Date).ToString("o") } |
        ConvertTo-Json | Set-Content -Path $CONFIG_FILE -Encoding UTF8
    Write-Log "Credential saved" "OK"
}

function Load-Credential {
    if (Test-Path $CONFIG_FILE) {
        $d = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json
        return @{ Username=$d.Username; Password=$d.Password; Carrier=$d.Carrier }
    }
    return $null
}

function Get-MyIP {
    try {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "WLAN" -ErrorAction SilentlyContinue |
               Where-Object { $_.IPAddress -match "^10\." } | Select-Object -First 1).IPAddress
        if ($ip) { return $ip }
    } catch {}
    return "0.0.0.0"
}

function Wait-ForIP {
    param([int]$MaxWait = 30)
    $w = 0
    while ($w -lt $MaxWait) {
        $ip = Get-MyIP
        if ($ip -ne "0.0.0.0") { return $ip }
        Start-Sleep -Seconds 2; $w += 2
    }
    return "0.0.0.0"
}

function Wait-ForAuthServer {
    param([int]$MaxWait = 60)
    $w = 0
    while ($w -lt $MaxWait) {
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $result = $tcp.BeginConnect($AUTH_HOST, $AUTH_PORT, $null, $null)
            $success = $result.AsyncWaitHandle.WaitOne(2000)
            if ($success) { $tcp.EndConnect($result); $tcp.Close(); return $true }
            $tcp.Close()
        } catch {}
        $w += 2
        if ($w % 10 -eq 0) { Write-Log ("Waiting for auth server... " + $w + "s") "WARN" }
        Start-Sleep -Seconds 2
    }
    return $false
}

function Test-WifiConnected {
    $out = netsh wlan show interfaces 2>$null | Select-String ("SSID\s+: " + $WIFI_SSID)
    return ($null -ne $out)
}

function Connect-Wifi {
    Write-Log ("Connecting to " + $WIFI_SSID)
    $xml = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>$WIFI_SSID</name>
  <SSIDConfig><SSID><name>$WIFI_SSID</name></SSID></SSIDConfig>
  <connectionType>ESS</connectionType>
  <connectionMode>manual</connectionMode>
  <MSM><security><authEncryption><authentication>open</authentication><encryption>none</encryption></authEncryption></security></MSM>
</WLANProfile>
"@
    $f = "$env:TEMP\ecjtu_wifi.xml"
    Set-Content -Path $f -Value $xml -Encoding UTF8
    netsh wlan add profile filename="$f" interface="WLAN" >$null 2>&1
    netsh wlan connect name="$WIFI_SSID" interface="WLAN" >$null 2>&1
    $w = 0
    while ($w -lt 30) {
        Start-Sleep -Seconds 2; $w += 2
        if (Test-WifiConnected) { Write-Log "WiFi connected" "OK"; return $true }
    }
    Write-Log "WiFi connect timeout" "ERROR"
    return $false
}

function Test-AlreadyOnline {
    try {
        $resp = Invoke-WebRequest -Uri $QUERY_URL -Method GET -TimeoutSec 5 -UseBasicParsing
        $bytes = $resp.RawContentStream.ToArray()
        $content = [System.Text.Encoding]::GetEncoding("gb2312").GetString($bytes)
        if ($content -match "uid='([^']*)'") {
            $uid = $Matches[1]
            if ($uid -ne "") {
                Write-Log ("Already online: " + $uid) "OK"
                return $true
            }
        }
    } catch {}
    return $false
}

function Invoke-DrcomLogin {
    param([string]$User, [string]$Pwd)
    if (-not (Test-WifiConnected)) {
        Write-Log "WiFi not connected, connecting..." "WARN"
        if (-not (Connect-Wifi)) { return $false }
    }

    Write-Log "Waiting for IP..."
    $ip = Wait-ForIP -MaxWait 30
    if ($ip -eq "0.0.0.0") {
        Write-Log "No valid IP assigned" "ERROR"
        return $false
    }

    Write-Log "Waiting for auth server..."
    if (-not (Wait-ForAuthServer -MaxWait 30)) {
        Write-Log "Auth server unreachable" "ERROR"
        return $false
    }

    $suffix = $CARRIERS[$Carrier]
    $account = $User + $suffix
    Write-Log ("Auth: " + $account + " ip=" + $ip)
    $body = "DDDDD=" + [System.Net.WebUtility]::UrlEncode($account) +
            "&upass=" + [System.Net.WebUtility]::UrlEncode($Pwd) +
            "&0MKKey=&username=&password=&user=&cmd=&Login="
    try {
        $resp = Invoke-WebRequest -Uri $LOGIN_URL -Method POST -Body $body `
            -ContentType "application/x-www-form-urlencoded" -TimeoutSec 15 -UseBasicParsing
        $bytes = $resp.RawContentStream.ToArray()
        $content = [System.Text.Encoding]::GetEncoding("gb2312").GetString($bytes)
        if ($content -match "Dr\.COMWebLoginID_3" -or $content -match "success") {
            Write-Log "Login OK" "OK"; return $true
        }
        elseif ($content -match "Dr\.COMWebLoginID_2" -or $content -match "fail") {
            Write-Log "Login failed" "ERROR"; return $false
        }
        else {
            Write-Log ("Resp: " + $content.Substring(0, [Math]::Min(200, $content.Length))) "WARN"
            return $true
        }
    } catch {
        Write-Log ("Login err: " + $_.Exception.Message) "ERROR"
        return $false
    }
}

function Invoke-DrcomLogout {
    Write-Log "Logging out..."
    try {
        Invoke-WebRequest -Uri $LOGOUT_URL -Method GET -TimeoutSec 10 -UseBasicParsing | Out-Null
        Write-Log "Logged out" "OK"; return $true
    } catch {
        Write-Log ("Logout err: " + $_.Exception.Message) "ERROR"; return $false
    }
}

function Get-DrcomStatus {
    Write-Log "Querying status..."
    try {
        $resp = Invoke-WebRequest -Uri $QUERY_URL -Method GET -TimeoutSec 10 -UseBasicParsing
        $bytes = $resp.RawContentStream.ToArray()
        $content = [System.Text.Encoding]::GetEncoding("gb2312").GetString($bytes)
        if ($content -match "uid='([^']*)'") {
            Write-Log ("Online: " + $Matches[1]) "OK"
        }
        if ($content -match "flow='(\d+)'") {
            $gb = [double]$Matches[1] / 1024
            Write-Log ("Traffic: " + [Math]::Round($gb,2) + " GB")
        }
        if ($content -match "time='(\d+)'") {
            $t = [int]$Matches[1]
            Write-Log ("Online time: " + [Math]::Floor($t/60) + "h " + ($t%60) + "m")
        }
        return $true
    } catch {
        Write-Log "Query failed" "WARN"; return $false
    }
}

function Test-InternetAccess {
    try {
        $r = Invoke-WebRequest -Uri "http://www.msftconnecttest.com/connecttest.txt" -TimeoutSec 5 -UseBasicParsing
        return ($r.Content -eq "Microsoft Connect Test")
    } catch { return $false }
}

function Start-Login {
    param([string]$User, [string]$Pwd)
    Write-Log "========== ECJTU WiFi Auto Login =========="

    if (Test-AlreadyOnline) {
        if (Test-InternetAccess) {
            Write-Log "Already online and internet OK, skip login" "OK"
            return $true
        }
        Write-Log "Online but no internet, re-login..." "WARN"
        Invoke-DrcomLogout | Out-Null
        Start-Sleep -Seconds 3
    }

    for ($i = 1; $i -le $RetryCount; $i++) {
        Write-Log ("Attempt " + $i + "/" + $RetryCount)
        if (Invoke-DrcomLogin -User $User -Pwd $Pwd) {
            Start-Sleep -Seconds 3
            if (Test-InternetAccess) {
                Write-Log "Internet OK" "OK"; return $true
            } else {
                Write-Log "Auth OK but no internet" "WARN"
            }
        }
        if ($i -lt $RetryCount) {
            Write-Log ("Wait " + $RetryDelay + "s...")
            Start-Sleep -Seconds $RetryDelay
        }
    }
    Write-Log "Failed after max retries" "ERROR"
    return $false
}

function Start-KeepAlive {
    param([string]$User, [string]$Pwd)
    Write-Log "========== KeepAlive Mode =========="
    Write-Log ("Interval: " + $KeepAliveInterval + "s | Ctrl+C to quit")
    while ($true) {
        if (-not (Test-InternetAccess)) {
            Write-Log "Network lost, reconnecting..." "WARN"
            Invoke-DrcomLogin -User $User -Pwd $Pwd | Out-Null
        } else {
            Write-Log ("OK " + (Get-Date -Format "HH:mm:ss"))
        }
        Start-Sleep -Seconds $KeepAliveInterval
    }
}

# ===== Entry =====
try {
    if ($Logout) { Invoke-DrcomLogout; exit 0 }
    if ($Status) { Get-DrcomStatus; exit 0 }

    $cred = $null
    if ($Username -and $Password) {
        $cred = @{ Username=$Username; Password=$Password }
    } elseif ($Auto) {
        $cred = Load-Credential
        if (-not $cred) { Write-Log "No saved creds, run without -Auto first" "ERROR"; exit 1 }
    } else {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  ECJTU-Stu Campus WiFi Login" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        $saved = Load-Credential
        if ($saved) {
            Write-Host ("Saved: " + $saved.Username) -ForegroundColor Yellow
            $use = Read-Host "Use saved? (Y/n)"
            if ($use -ne "n") { $cred = $saved }
        }
        if (-not $cred) {
            $u = Read-Host "Student ID"
            $p = Read-Host "Password" -AsSecureString
            $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p))
            Write-Host ""
            Write-Host "Carrier:" -ForegroundColor Cyan
            Write-Host "  1. Campus @xyw"
            Write-Host "  2. ChinaMobile @cmcc"
            Write-Host "  3. ChinaTelecom @dx"
            Write-Host "  4. ChinaUnicom @lt"
            $ch = Read-Host "Select [1-4] (default: 2)"
            $Carrier = switch ($ch) { "1" {"xyw"} "3" {"dx"} "4" {"lt"} default {"cmcc"} }
            $cred = @{ Username=$u; Password=$plain }
            $sv = Read-Host "Save credentials? (Y/n)"
            if ($sv -ne "n") { Save-Credential -U $u -P $plain }
        }
    }

    if (-not $cred) { Write-Log "No credentials" "ERROR"; exit 1 }
    if ($cred.Carrier) { $Carrier = $cred.Carrier }

    if ($KeepAlive) {
        Start-KeepAlive -User $cred.Username -Pwd $cred.Password
    } else {
        if (Start-Login -User $cred.Username -Pwd $cred.Password) {
            Write-Host ""
            Write-Host "Login complete, internet ready" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "Login failed" -ForegroundColor Red
            exit 1
        }
    }
} catch {
    Write-Log ("Error: " + $_.Exception.Message) "ERROR"
    exit 1
}
