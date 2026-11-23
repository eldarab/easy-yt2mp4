# Draws the desktop icon (a red play button with a white arrow pointing down)
# and writes it to src\icon.ico. Run once after changing the design.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-IconPng {
    param([int]$Size)
    $bmp = New-Object System.Drawing.Bitmap ($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)

    $s = $Size / 256.0
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = 56 * $s; $x = 8 * $s; $y = 28 * $s; $w = 240 * $s; $h = 200 * $s
    $path.AddArc($x, $y, $r, $r, 180, 90)
    $path.AddArc($x + $w - $r, $y, $r, $r, 270, 90)
    $path.AddArc($x + $w - $r, $y + $h - $r, $r, $r, 0, 90)
    $path.AddArc($x, $y + $h - $r, $r, $r, 90, 90)
    $path.CloseFigure()
    $red = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 220, 30, 30))
    $g.FillPath($red, $path)

    # Arrow pointing down
    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $g.FillRectangle($white, [single](104 * $s), [single](62 * $s), [single](48 * $s), [single](70 * $s))
    $arrow = @(
        (New-Object System.Drawing.PointF ([single](64 * $s), [single](128 * $s))),
        (New-Object System.Drawing.PointF ([single](192 * $s), [single](128 * $s))),
        (New-Object System.Drawing.PointF ([single](128 * $s), [single](194 * $s)))
    )
    $g.FillPolygon($white, $arrow)
    $g.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $script:Images.Add($ms.ToArray())
}

$sizes = @(256, 48, 32, 16)
$script:Images = New-Object 'System.Collections.Generic.List[byte[]]'
foreach ($size in $sizes) { New-IconPng $size }
$images = $script:Images

$out = New-Object System.IO.MemoryStream
$wr = New-Object System.IO.BinaryWriter ($out)
$wr.Write([uint16]0); $wr.Write([uint16]1); $wr.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $dim = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
    $wr.Write([byte]$dim); $wr.Write([byte]$dim); $wr.Write([byte]0); $wr.Write([byte]0)
    $wr.Write([uint16]1); $wr.Write([uint16]32)
    $wr.Write([uint32]$images[$i].Length); $wr.Write([uint32]$offset)
    $offset += $images[$i].Length
}
foreach ($img in $images) { $wr.Write($img) }
$wr.Flush()
$target = Join-Path $PSScriptRoot '..\src\icon.ico'
[System.IO.File]::WriteAllBytes([System.IO.Path]::GetFullPath($target), $out.ToArray())
Write-Host "Wrote $target"
