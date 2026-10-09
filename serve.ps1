# Simple HTTP server for PSH Dashboard testing
# Usage: Right-click > Run with PowerShell  OR  .\serve.ps1 in terminal

$port   = 8080
$folder = Split-Path -Parent $MyInvocation.MyCommand.Path

$url = "http://localhost:$port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)

try { $listener.Start() }
catch {
    Write-Host "❌ Gagal mulakan server: $_" -ForegroundColor Red
    Write-Host "Cuba tukar port atau jalankan sebagai Administrator." -ForegroundColor Yellow
    pause; exit
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   PSH Dashboard – Local Test Server          ║" -ForegroundColor Cyan
Write-Host "╠══════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║                                              ║" -ForegroundColor Cyan
Write-Host "║  🔐 Login      : http://localhost:$port/login.html  ║" -ForegroundColor Cyan
Write-Host "║  📊 Admin      : http://localhost:$port/admin-dashboard.html  ║" -ForegroundColor Cyan
Write-Host "║  🏢 Jabatan    : http://localhost:$port/dept-dashboard%%20(1).html  ║" -ForegroundColor Cyan
Write-Host "║                                              ║" -ForegroundColor Cyan
Write-Host "║  Tekan Ctrl+C untuk henti server             ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Auto-open browser to login page
Start-Process "http://localhost:$port/login.html"

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".json" = "application/json"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".ico"  = "image/x-icon"
    ".svg"  = "image/svg+xml"
    ".woff2"= "font/woff2"
}

while ($listener.IsListening) {
    try {
        $ctx      = $listener.GetContext()
        $req      = $ctx.Request
        $resp     = $ctx.Response
        $rawPath  = $req.Url.AbsolutePath

        # URL-decode the path (handles spaces like "dept-dashboard (1).html")
        $decoded  = [System.Uri]::UnescapeDataString($rawPath.TrimStart('/'))
        if ($decoded -eq '' -or $decoded -eq '/') { $decoded = 'login.html' }

        $filePath = Join-Path $folder $decoded

        if (Test-Path $filePath -PathType Leaf) {
            $ext      = [System.IO.Path]::GetExtension($filePath).ToLower()
            $mime     = if ($mimeTypes[$ext]) { $mimeTypes[$ext] } else { "application/octet-stream" }
            $content  = [System.IO.File]::ReadAllBytes($filePath)
            $resp.ContentType   = $mime
            $resp.ContentLength64 = $content.Length
            $resp.StatusCode    = 200
            $resp.OutputStream.Write($content, 0, $content.Length)
            Write-Host "  200  $rawPath" -ForegroundColor Green
        } else {
            $body     = [System.Text.Encoding]::UTF8.GetBytes("<h2>404 – Fail tidak dijumpai: $decoded</h2>")
            $resp.StatusCode    = 404
            $resp.ContentType   = "text/html"
            $resp.ContentLength64 = $body.Length
            $resp.OutputStream.Write($body, 0, $body.Length)
            Write-Host "  404  $rawPath" -ForegroundColor Red
        }
        $resp.OutputStream.Close()
    } catch [System.Net.HttpListenerException] {
        # Listener stopped (Ctrl+C)
        break
    } catch {
        Write-Host "  ERR  $_" -ForegroundColor Yellow
        try { $resp.OutputStream.Close() } catch {}
    }
}

$listener.Stop()
Write-Host "`nServer dihenti." -ForegroundColor Gray
