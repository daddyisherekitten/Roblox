param(
    [Parameter(Mandatory=$true)][string]$ArchivePath,
    [Parameter(Mandatory=$true)][string]$RegistryPath,
    [string]$SelectedPath,
    [string]$SourcePathsPath,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class WikiPixels {
    public static byte[] RGBA(Image source) {
        // Read straight ARGB directly. A Graphics.DrawImage intermediate loses
        // low-alpha RGB samples through premultiplied drawing and unpremultiply.
        var bitmap = (Bitmap)source;
            var data = bitmap.LockBits(new Rectangle(0, 0, bitmap.Width, bitmap.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try {
                var rgba = new byte[checked(bitmap.Width * bitmap.Height * 4)];
                var row = new byte[bitmap.Width * 4];
                for (int y = 0; y < bitmap.Height; y++) {
                    Marshal.Copy(IntPtr.Add(data.Scan0, y * data.Stride), row, 0, row.Length);
                    for (int x = 0; x < bitmap.Width; x++) {
                        int src = x * 4, dst = (y * bitmap.Width + x) * 4;
                        rgba[dst] = row[src + 2]; rgba[dst + 1] = row[src + 1];
                        rgba[dst + 2] = row[src]; rgba[dst + 3] = row[src + 3];
                    }
                }
                return rgba;
            } finally { bitmap.UnlockBits(data); }
    }
}
'@ -ReferencedAssemblies System.Drawing
$registry = Get-Content -LiteralPath $RegistryPath -Raw | ConvertFrom-Json
if ($registry.Registry) { $entries = @($registry.Registry) } else { $entries = @($registry) }
if ($SourcePathsPath) {
    # Explicit publisher dependency closure: never bring an unselected site in
    # through an implicit, global image directory.
    $sourcePaths = Get-Content -LiteralPath $SourcePathsPath -Raw | ConvertFrom-Json
    $allowed = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($member in $sourcePaths) {
        if ($member -isnot [string] -or -not $member.StartsWith('/') -or $member.Contains('\') -or ($member -split '/') -contains '..') { throw 'Invalid selected image source path' }
        [void]$allowed.Add($member)
    }
    $images = @($entries | Where-Object { $allowed.Contains($_.Path) -and $_.Path -match '\.(png|jpe?g|gif)$' })
} elseif ($SelectedPath) {
    $selected = Get-Content -LiteralPath $SelectedPath -Raw | ConvertFrom-Json
    $roots = @('wiki1','wiki2','wiki3') + @($selected.sites.DocumentRoot)
    $images = @($entries | Where-Object { ($_.Path -split '/')[1] -in $roots -and $_.Path -match '\.(png|jpe?g|gif)$' })
} else { throw 'Supply -SelectedPath or an explicit -SourcePathsPath' }
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$stream = [IO.File]::OpenRead($ArchivePath)
$results = [Collections.Generic.List[object]]::new()
$sha = [Security.Cryptography.SHA256]::Create()
try {
    foreach ($entry in $images) {
        $bytes = New-Object byte[] $entry.Length
        $stream.Position = $entry.Offset
        $read = 0
        while ($read -lt $bytes.Length) {
            $count = $stream.Read($bytes, $read, $bytes.Length - $read)
            if ($count -eq 0) { throw 'Unexpected archive end' }
            $read += $count
        }
        $memory = New-Object IO.MemoryStream(,$bytes)
        $image = $null
        try {
            $image = [Drawing.Image]::FromStream($memory)
            $frames = 1
            if ($image.FrameDimensionsList -contains [Drawing.Imaging.FrameDimension]::Time.Guid) {
                $frames = $image.GetFrameCount([Drawing.Imaging.FrameDimension]::Time)
            }
            $rgba = [WikiPixels]::RGBA($image)
            $name = 'image-' + $results.Count.ToString('D3') + '.rgba'
            [IO.File]::WriteAllBytes((Join-Path $OutputDirectory $name), $rgba)
            $sourceHash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant()
            $pixelHash = [BitConverter]::ToString($sha.ComputeHash($rgba)).Replace('-','').ToLowerInvariant()
            $results.Add([pscustomobject]@{Path=$entry.Path;Width=$image.Width;Height=$image.Height;Frames=$frames;FrameSelection=0;File=$name;Bytes=$rgba.Length;SourceSHA256=$sourceHash;RGBASHA256=$pixelHash})
        } finally {
            if ($null -ne $image) { $image.Dispose() }
            $memory.Dispose()
        }
    }
} finally { $stream.Dispose(); $sha.Dispose() }
$json = ConvertTo-Json -InputObject @($results.ToArray()) -Depth 5
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'decoded.json'), $json, (New-Object Text.UTF8Encoding($false)))
Write-Output ('Decoded {0} original images to RGBA; source archive unchanged.' -f $results.Count)
