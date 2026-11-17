# Graviddle - yayina hazirlama araci
# bulmacalar.txt (Berra'nin calisma dosyasi, GitHub'a gitmez) dosyasindan
# sitenin okudugu sifreli kopyayi uretir:
#   - bulmacalar.dat               (sitenin indirdigi dosya)
#   - index.html icindeki yedek    (dosya indirilemezse kullanilan kopya)
# Yalnizca "durum: hazır" bulmacalar alinir; yorumlar, tuzak:/kaynak: satirlari ve
# taslaklar cikarilir (satir numaralari bozulmasin diye bos satir birakilir).
# Girintili "okuma:" satirlari (oyuncunun gorecegi kaynak) KALIR; yalnizca satir
# basindaki tuzak:/kaynak: silinir.
# "yayınla: #1, FS #1" satiri varsa yalnizca o bulmacalar alinir.
# Sifreleme gercek bir kilit degil; cevaplarin goz ucuyla gorulmesini engeller.
# Anahtar index.html icindeki GRV_KEY ile ayni olmali.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root "bulmacalar.txt"
$dat  = Join-Path $root "bulmacalar.dat"
$html = Join-Path $root "index.html"
$KEY  = "Her gun bir elma duser"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$lines = [IO.File]::ReadAllText($src, $utf8).Replace("`r", "").Split("`n")

# 1) Bulmaca bloklarini bul
$heads = @()
for ($i = 0; $i -lt $lines.Length; $i++) {
  $m = [regex]::Match($lines[$i].Trim(), '^===\s*(fizik[çc]inin\s+se[çc]imi|fs)?\s*#?\s*(\d+)\s*$', 'IgnoreCase')
  if ($m.Success) { $heads += ,@($i, [bool]$m.Groups[1].Success, [int]$m.Groups[2].Value) }
}

# 2) "yayınla:" listesi (bulmacalardan once)
$first = if ($heads.Count) { $heads[0][0] } else { $lines.Length }
$only = $null
for ($i = 0; $i -lt $first; $i++) {
  $m = [regex]::Match($lines[$i].Trim(), '^yay[ıi]nla\s*:\s*(.*)$', 'IgnoreCase')
  if ($m.Success) {
    $only = @{}
    foreach ($part in $m.Groups[1].Value.Split(',')) {
      $pm = [regex]::Match($part.Trim(), '^(fizik[çc]inin\s+se[çc]imi|fs)?\s*#?\s*(\d+)$', 'IgnoreCase')
      if ($pm.Success) { $only[("{0}{1}" -f $(if ($pm.Groups[1].Success) { "FS" } else { "" }), [int]$pm.Groups[2].Value)] = $true }
      elseif ($part.Trim()) { throw "yayınla: satırındaki '$($part.Trim())' anlaşılamadı (örnek: yayınla: #1, FS #1)" }
    }
    $lines[$i] = ""
  }
}

# 3) Satirlari temizle
$out = New-Object string[] $lines.Length
for ($i = 0; $i -lt $lines.Length; $i++) {
  $t = $lines[$i].Trim()
  if ($t.StartsWith("#")) { $out[$i] = "" } else { $out[$i] = $lines[$i] }
}

$published = @(); $skipped = @()
for ($h = 0; $h -lt $heads.Count; $h++) {
  $s = $heads[$h][0]; $isB = $heads[$h][1]; $n = $heads[$h][2]
  $e = if ($h + 1 -lt $heads.Count) { $heads[$h + 1][0] } else { $lines.Length }
  $name = if ($isB) { "FS #$n" } else { "#$n" }
  $id = $(if ($isB) { "FS" } else { "" }) + $n
  $ready = $false
  for ($i = $s + 1; $i -lt $e; $i++) {
    if ($lines[$i] -match '^\s*durum\s*:\s*haz[ıi]r\s*$') { $ready = $true }
  }
  $keep = $ready -and (($only -eq $null) -or $only.ContainsKey($id))
  for ($i = $s; $i -lt $e; $i++) {
    if (-not $keep) { $out[$i] = "" }
    elseif ($lines[$i] -match '^(tuzak|kaynak)\s*:') { $out[$i] = "" }
  }
  if ($keep) { $published += $name } else { $skipped += $name }
}

$text = ([string]::Join("`n", $out)).TrimEnd() + "`n"

# 4) Sifrele
$bytes = $utf8.GetBytes($text)
$k = [Text.Encoding]::ASCII.GetBytes($KEY)
for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] = $bytes[$i] -bxor $k[$i % $k.Length] }
$enc = "GRVB1:" + [Convert]::ToBase64String($bytes)

[IO.File]::WriteAllText($dat, $enc + "`n", $utf8)

# 5) index.html icindeki yedegi guncelle
$open = '<script type="text/plain" id="bulmacalar-yedek">'
$page = [IO.File]::ReadAllText($html, $utf8)
$a = $page.IndexOf($open)
if ($a -lt 0) { throw "index.html içinde bulmacalar-yedek bulunamadı" }
$a += $open.Length
$b = $page.IndexOf("</script>", $a)
$page = $page.Substring(0, $a) + "`n" + $enc + "`n" + $page.Substring($b)
[IO.File]::WriteAllText($html, $page, $utf8)

Write-Host ""
Write-Host "Hazır. Siteye gidecek bulmacalar: $($published -join ', ')"
if ($skipped.Count) { Write-Host "Gitmeyenler (taslak ya da yayınla: listesinde yok): $($skipped -join ', ')" }
Write-Host "Not: Değişiklik GitHub'a yüklenince sitede görünür."
