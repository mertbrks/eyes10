# eyes10: sistem tepsisinde tek tık ile bilgisayarı (kapak kapalıyken de) uyanık tutar.
# Sol tık: aç/kapat. Sağ tık: süre seçimi ve çıkış. Kapanınca kapak ayarını eski haline döndürür.
param([switch]$Test, [switch]$Dene)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Namespace W -Name K -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f);'

$ES_CONTINUOUS = [uint32]2147483648; $ES_SYSTEM = [uint32]1
$PIL_SINIRI = 20   # pil bu yüzdenin altına inince (şarjda değilken) kendini kapatır

function Get-Lid {
    $m = [regex]::Matches((powercfg /qh SCHEME_CURRENT SUB_BUTTONS LIDACTION | Out-String), '0x[0-9a-fA-F]{8}')
    if ($m.Count -lt 2) { throw 'Kapak ayarı okunamadı' }
    @([Convert]::ToInt32($m[$m.Count-2].Value, 16), [Convert]::ToInt32($m[$m.Count-1].Value, 16))  # AC, DC
}
function Set-Lid($ac, $dc) {
    powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION $ac
    powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION $dc
    powercfg /setactive SCHEME_CURRENT
}

if ($Test) {  # kendi kendini sına: kapağı değiştirip geri al
    $eski = Get-Lid; Set-Lid 0 0
    if ((Get-Lid) -join ',' -ne '0,0') { throw 'Kapak ayarı yazılamadı' }
    Set-Lid $eski[0] $eski[1]
    if ((Get-Lid) -join ',' -ne ($eski -join ',')) { throw 'Kapak ayarı geri yüklenemedi' }
    "OK: kapak ayarı $($eski -join ',') -> 0,0 -> geri yüklendi"; return
}

# Göz ikonu: $o = açıklık (0 kapalı, kirpikli "‿"; 1 tam açık, gözbebekli)
function New-Goz([double]$o) {
    $renk = if ($o -gt 0) { [System.Drawing.Color]::FromArgb(30, 130, 65) } else { [System.Drawing.Color]::FromArgb(200, 40, 40) }  # açık: koyu yeşil, kapalı: kırmızı
    $b = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($b); $g.SmoothingMode = 'AntiAlias'
    $kalem = New-Object System.Drawing.Pen $renk, 2.4
    $kalem.StartCap = $kalem.EndCap = 'Round'
    $ust = 22 - 16 * $o   # üst kapağın kontrol noktası kalktıkça göz açılır
    $yol = New-Object System.Drawing.Drawing2D.GraphicsPath
    $yol.AddBezier(3, 16, 10, $ust, 22, $ust, 29, 16); $yol.AddBezier(29, 16, 22, 22, 10, 22, 3, 16)
    if ($o -gt 0.15) {
        $g.SetClip($yol)
        $r = 5 * [Math]::Min(1, $o * 1.3)
        $g.FillEllipse((New-Object System.Drawing.SolidBrush $renk), 16 - $r, 15.5 - $r, 2 * $r, 2 * $r)
        $g.ResetClip()
        $g.DrawPath($kalem, $yol)
        foreach ($t in 0.2, 0.5, 0.8) {   # üst kapaktaki kirpikler, göz merkezinden dışa doğru
            $a = 1 - $t
            $x = 3*$a*$a*$a + 30*$a*$a*$t + 66*$a*$t*$t + 29*$t*$t*$t
            $y = 16*($a*$a*$a + $t*$t*$t) + 3*$ust*$a*$t
            $dx = $x - 16; $dy = $y - 20; $n = [Math]::Sqrt($dx*$dx + $dy*$dy); $L = 4.5 * $o
            $g.DrawLine($kalem, [single]$x, [single]$y, [single]($x + $dx/$n*$L), [single]($y + $dy/$n*$L))
        }
    } else {
        $g.DrawBezier($kalem, 3, 16, 10, 22, 22, 22, 29, 16)
        foreach ($l in @(@(8.5, 19.5, 6, 24), @(16, 20.5, 16, 26), @(23.5, 19.5, 26, 24))) { $g.DrawLine($kalem, $l[0], $l[1], $l[2], $l[3]) }
    }
    $g.Dispose(); [System.Drawing.Icon]::FromHandle($b.GetHicon())
}
$kareler = 0..5 | % { New-Goz ($_ / 5) }

$script:eskiKapak = $null; $script:bitis = $null; $script:kare = 0; $script:hedef = 0
$ni = New-Object System.Windows.Forms.NotifyIcon
$ni.Icon = $kareler[0]; $ni.Text = 'eyes10: kapalı'; $ni.Visible = $true

$anim = New-Object System.Windows.Forms.Timer; $anim.Interval = 45
$anim.add_Tick({
    if ($script:kare -eq $script:hedef) { $anim.Stop(); return }
    $script:kare += [Math]::Sign($script:hedef - $script:kare); $ni.Icon = $kareler[$script:kare]
})
function Goz([int]$hedef) { $script:hedef = $hedef; $anim.Start() }

function Baslat([double]$saat) {
    if (-not $script:eskiKapak) { $script:eskiKapak = Get-Lid }
    Set-Lid 0 0
    [void][W.K]::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM)
    $script:bitis = if ($saat -gt 0) { (Get-Date).AddHours($saat) } else { $null }
    Goz 5; Guncelle
}
function Durdur {
    [void][W.K]::SetThreadExecutionState($ES_CONTINUOUS)
    if ($script:eskiKapak) { Set-Lid $script:eskiKapak[0] $script:eskiKapak[1]; $script:eskiKapak = $null }
    $script:bitis = $null; Goz 0; $ni.Text = 'eyes10: kapalı'
}
function Guncelle {
    if (-not $script:eskiKapak) { return }
    if ($script:bitis) {
        $kalan = $script:bitis - (Get-Date)
        if ($kalan.TotalSeconds -le 0) { Durdur; $ni.ShowBalloonTip(3000, 'eyes10', 'Süre doldu, uyku normale döndü.', 'Info'); return }
        $ni.Text = 'eyes10: açık, kalan {0:hh\:mm\:ss}' -f $kalan
    } else { $ni.Text = 'eyes10: açık (süresiz)' }
    $pil = [System.Windows.Forms.SystemInformation]::PowerStatus
    if ($pil.PowerLineStatus -eq 'Offline' -and $pil.BatteryLifePercent * 100 -lt $PIL_SINIRI) {
        Durdur; $ni.ShowBalloonTip(3000, 'eyes10', "Pil %$PIL_SINIRI altına düştü, kapatıldı.", 'Warning')
    }
}

$log = Join-Path $PSScriptRoot 'hata.log'
function Guvenli($is) { try { & $is } catch { "$(Get-Date -f s) $($_ | Out-String)" | Add-Content $log; $ni.ShowBalloonTip(3000, 'eyes10 hata', "$_", 'Error') } }

if ($Dene) { Guvenli { Baslat 8 }; "acik: $((Get-Lid) -join ',') $($ni.Text)"; Guvenli { Durdur }; "kapali: $((Get-Lid) -join ',') $($ni.Text)"; $ni.Dispose(); return }

$menu = New-Object System.Windows.Forms.ContextMenuStrip
# süre öğenin Tag'inde; GetNewClosure betiğin fonksiyonlarını göremediği için kullanılmadı
foreach ($s in 1, 2, 4, 8, 0) {
    $o = $menu.Items.Add($(if ($s) { "$s saat" } else { 'Süresiz' })); $o.Tag = $s
    $o.add_Click({ param($k) Guvenli { Baslat $k.Tag } })
}
[void]$menu.Items.Add('Kapat', $null, { Guvenli { Durdur } })
[void]$menu.Items.Add('-')
[void]$menu.Items.Add('Çıkış', $null, { Guvenli { Durdur }; $ni.Visible = $false; [System.Windows.Forms.Application]::Exit() })
$ni.ContextMenuStrip = $menu
$ni.add_MouseClick({ param($k, $e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Guvenli { if ($script:eskiKapak) { Durdur } else { Baslat 1 } } } })

$t = New-Object System.Windows.Forms.Timer; $t.Interval = 1000; $t.add_Tick({ Guvenli { Guncelle } }); $t.Start()
try { [System.Windows.Forms.Application]::Run() } finally { Durdur; $ni.Dispose() }
