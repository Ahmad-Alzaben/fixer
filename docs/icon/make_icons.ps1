# Renders docs/icon/fixer-icon.svg into all Android and iOS launcher icons.
param([string]$Project = 'C:\Users\Asus\Documents\projects\bill_splitter')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$work = Join-Path $env:TEMP 'fixer-icons'
New-Item -ItemType Directory -Force $work | Out-Null
$chrome = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
$svg = Get-Content -Raw "$Project\docs\icon\fixer-icon.svg"

function Render([string]$svgText, [string]$name, [bool]$transparent) {
  $svgPath = Join-Path $work "$name.svg"
  $png = Join-Path $work "$name.png"
  Set-Content -Path $svgPath -Value $svgText -Encoding utf8
  $chromeArgs = @('--headless=new', '--disable-gpu', '--hide-scrollbars',
            '--window-size=1024,1024', "--screenshot=$png")
  if ($transparent) { $chromeArgs += '--default-background-color=00000000' }
  $chromeArgs += ('file:///' + ($svgPath -replace '\\', '/'))
  # Chrome reports success on stderr; don't treat that as a failure.
  $ErrorActionPreference = 'Continue'
  & $chrome @chromeArgs 2>&1 | Out-Null
  $ErrorActionPreference = 'Stop'
  Start-Sleep -Seconds 2
  if (-not (Test-Path $png)) { throw "Render failed: $name" }
  return $png
}

function Resize([string]$src, [string]$dest, [int]$size) {
  $img = [System.Drawing.Image]::FromFile($src)
  $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.DrawImage($img, 0, 0, $size, $size)
  New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
  $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose(); $img.Dispose()
}

# 1. Full icon (opaque): iOS and legacy Android.
$full = Render $svg 'full' $false

# 2. Adaptive foreground: no background, scaled to 88% so circular masks
#    keep the whole coin.
$fg = $svg -replace '<rect width="1024" height="1024" fill="#0A0A0F"/>', ''
$fg = $fg -replace '(<!-- Card with the top-right corner cut -->)', '<g transform="translate(512 512) scale(0.88) translate(-512 -512)">$1'
$fg = $fg -replace '</svg>\s*$', "</g>`n</svg>"
$fore = Render $fg 'foreground' $true

$res = "$Project\android\app\src\main\res"
$legacy = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
foreach ($d in $legacy.Keys) {
  Resize $full "$res\mipmap-$d\ic_launcher.png" $legacy[$d]
  # Adaptive foreground is 108dp per density.
  Resize $fore "$res\mipmap-$d\ic_launcher_foreground.png" ([int]($legacy[$d] * 108 / 48))
}

# 3. iOS: overwrite every PNG in the app icon set at its existing size.
$ios = "$Project\ios\Runner\Assets.xcassets\AppIcon.appiconset"
Get-ChildItem $ios -Filter *.png | ForEach-Object {
  $existing = [System.Drawing.Image]::FromFile($_.FullName)
  $size = $existing.Width
  $existing.Dispose()
  Resize $full $_.FullName $size
}

# 4. Store / README sized copy.
Copy-Item $full "$Project\docs\icon\fixer-icon-1024.png" -Force
"done"
