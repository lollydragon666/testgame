param([int]$Port = 4173, [switch]$NoBrowser)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($PSScriptRoot)
$rooms = @{}
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Any, $Port)

function New-RoomCode {
  $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  do {
    $code = -join (1..4 | ForEach-Object { $alphabet[(Get-Random -Maximum $alphabet.Length)] })
  } while ($rooms.ContainsKey($code))
  return $code
}

function Send-Response($stream, [int]$status, [string]$contentType, [byte[]]$body) {
  $labels = @{ 200='OK'; 400='Bad Request'; 404='Not Found'; 409='Conflict'; 500='Server Error' }
  $header = "HTTP/1.1 $status $($labels[$status])`r`nContent-Type: $contentType`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
  $headerBytes = [Text.Encoding]::ASCII.GetBytes($header)
  $stream.Write($headerBytes, 0, $headerBytes.Length)
  if ($body.Length) { $stream.Write($body, 0, $body.Length) }
}

function Send-Json($stream, [int]$status, $value) {
  $json = $value | ConvertTo-Json -Depth 30 -Compress
  Send-Response $stream $status 'application/json; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes($json))
}

function Read-Request($stream) {
  $bytes = [Collections.Generic.List[byte]]::new()
  $buffer = [byte[]]::new(8192)
  $headerEnd = -1
  $contentLength = 0
  while ($true) {
    $read = $stream.Read($buffer, 0, $buffer.Length)
    if ($read -le 0) { break }
    for ($i = 0; $i -lt $read; $i++) { $bytes.Add($buffer[$i]) }
    if ($headerEnd -lt 0) {
      $preview = [Text.Encoding]::ASCII.GetString($bytes.ToArray())
      $headerEnd = $preview.IndexOf("`r`n`r`n")
      if ($headerEnd -ge 0 -and $preview.Substring(0, $headerEnd) -match '(?im)^Content-Length:\s*(\d+)') { $contentLength = [int]$Matches[1] }
    }
    if ($headerEnd -ge 0 -and $bytes.Count -ge ($headerEnd + 4 + $contentLength)) { break }
    if ($bytes.Count -gt 1048576) { throw 'Request too large' }
  }
  $all = $bytes.ToArray()
  if ($headerEnd -lt 0) { throw 'Invalid HTTP request' }
  $header = [Text.Encoding]::ASCII.GetString($all, 0, $headerEnd)
  $first = $header.Split("`r`n")[0].Split(' ')
  $bodyText = ''
  if ($contentLength -gt 0) { $bodyText = [Text.Encoding]::UTF8.GetString($all, $headerEnd + 4, $contentLength) }
  return @{ Method=$first[0]; Target=$first[1]; Body=$bodyText }
}

function Room-View($room) {
  return @($room.Players | ForEach-Object { @{ id=$_.Id; name=$_.Name; state=$_.State; attack=$_.Attack; slot=$_.Slot } })
}

function Handle-Api($stream, $request, $path) {
  try { $payload = if ($request.Body) { $request.Body | ConvertFrom-Json } else { [pscustomobject]@{} } }
  catch { Send-Json $stream 400 @{ok=$false; error='Invalid request'}; return }

  if ($path -eq '/api/create' -and $request.Method -eq 'POST') {
    $code = New-RoomCode
    $id = [Guid]::NewGuid().ToString('N')
    $player = @{ Id=$id; Name=[string]$payload.name; Slot=0; State=$null; Attack=0; LastSeen=[DateTime]::UtcNow }
    $room = @{ Code=$code; Players=[Collections.ArrayList]@($player); Created=[DateTime]::UtcNow }
    $rooms[$code] = $room
    Send-Json $stream 200 @{ok=$true; code=$code; playerId=$id; slot=0; players=(Room-View $room)}
    return
  }

  if ($path -eq '/api/join' -and $request.Method -eq 'POST') {
    $code = ([string]$payload.code).Trim().ToUpperInvariant()
    if (-not $rooms.ContainsKey($code)) { Send-Json $stream 404 @{ok=$false; error='Room not found'}; return }
    $room = $rooms[$code]
    if ($room.Players.Count -ge 2) { Send-Json $stream 409 @{ok=$false; error='Room is full'}; return }
    $id = [Guid]::NewGuid().ToString('N')
    $player = @{ Id=$id; Name=[string]$payload.name; Slot=1; State=$null; Attack=0; LastSeen=[DateTime]::UtcNow }
    [void]$room.Players.Add($player)
    Send-Json $stream 200 @{ok=$true; code=$code; playerId=$id; slot=1; players=(Room-View $room)}
    return
  }

  if ($path -eq '/api/sync' -and $request.Method -eq 'POST') {
    $code = ([string]$payload.code).Trim().ToUpperInvariant()
    if (-not $rooms.ContainsKey($code)) { Send-Json $stream 404 @{ok=$false; error='Room is closed'}; return }
    $room = $rooms[$code]
    $player = $room.Players | Where-Object { $_.Id -eq [string]$payload.playerId } | Select-Object -First 1
    if ($null -eq $player) { Send-Json $stream 404 @{ok=$false; error='Player not found'}; return }
    $player.LastSeen = [DateTime]::UtcNow
    if ($null -ne $payload.state) { $player.State = $payload.state }
    if ($null -ne $payload.attack) { $player.Attack = [int]$payload.attack }
    Send-Json $stream 200 @{ok=$true; code=$code; slot=$player.Slot; players=(Room-View $room)}
    return
  }

  Send-Json $stream 404 @{ok=$false; error='Route not found'}
}

function Handle-Static($stream, $path) {
  $relative = [Uri]::UnescapeDataString($path.TrimStart('/'))
  if ([string]::IsNullOrWhiteSpace($relative)) { $relative = 'index.html' }
  $file = [IO.Path]::GetFullPath((Join-Path $root $relative))
  if (-not $file.StartsWith($root) -or -not (Test-Path -LiteralPath $file -PathType Leaf)) {
    Send-Response $stream 404 'text/plain; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes('Not found'))
    return
  }
  $types = @{ '.html'='text/html; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.js'='text/javascript; charset=utf-8'; '.md'='text/plain; charset=utf-8' }
  $extension = [IO.Path]::GetExtension($file).ToLowerInvariant()
  $contentType = if ($types.ContainsKey($extension)) { $types[$extension] } else { 'application/octet-stream' }
  Send-Response $stream 200 $contentType ([IO.File]::ReadAllBytes($file))
}

try {
  $listener.Start()
  $addresses = [Net.Dns]::GetHostAddresses([Net.Dns]::GetHostName()) | Where-Object { $_.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork }
  Write-Host "`nDread Blocks server started" -ForegroundColor DarkYellow
  Write-Host "On this computer: http://127.0.0.1:$Port"
  foreach ($address in $addresses) { Write-Host "For friends on LAN: http://$address`:$Port" -ForegroundColor Green }
  Write-Host "Press Ctrl+C to stop.`n" -ForegroundColor DarkGray
  if (-not $NoBrowser) { Start-Process "http://127.0.0.1:$Port" }

  while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
      $client.ReceiveTimeout = 5000
      $stream = $client.GetStream()
      $request = Read-Request $stream
      $uri = [Uri]("http://localhost" + $request.Target)
      if ($uri.AbsolutePath.StartsWith('/api/')) { Handle-Api $stream $request $uri.AbsolutePath }
      else { Handle-Static $stream $uri.AbsolutePath }
    } catch {
      try { Send-Json $stream 500 @{ok=$false; error='Server error'} } catch {}
      Write-Warning $_.Exception.Message
    } finally {
      if ($null -ne $stream) { $stream.Dispose() }
      $client.Dispose()
    }
  }
} finally {
  $listener.Stop()
}
