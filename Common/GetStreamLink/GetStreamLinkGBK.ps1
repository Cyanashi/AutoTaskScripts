$Workspace = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $Workspace
$Version = "1.1.1"
$Updated = "2020-04-20"
$Source = "https://github.com/Cyanashi/AutoTaskScripts/tree/master/Common/GetStreamLink"

#=================================================
#   Author: Cyanashi
#   Version: 1.1.1
#   Updated: 2020-04-20
#   Required: ^PowerShell 5.1
#   Description: Live Stream-link Source Parsing Tool ֱ��Դ��ȡ����
#   Link: https://ews.ink/develop/Get-Stream-Link
#=================================================

$Script:Args # ���ظ�ֵ[ = $args] $Script:Args �Ѿ��ǲ�����
$Script:Config | Out-Null
$Script:Input | Out-Null
$Script:LiveInfo = @{ }
$Script:Stream = @{ }
$Script:AsxData = @{ }

Add-Type -AssemblyName System.Windows.Forms
function Get-MsgBox {
    param (
        [String]$Prompt = "Ĭ������",
        [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK,
        [String]$Title = "Ĭ�ϱ���",
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::None
    )
    return [System.Windows.Forms.MessageBox]::Show($Prompt, $Title, $Buttons, $Icon)
}

function Write-Log {
    [CmdletBinding()]
    param (
        [String]$Content,
        [String]$Level = "INFO"
    )
    $current = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Content = $Content.Replace("`n", "`n                      ")
    $log = "[$($current)] $($Level.ToUpper()) | $($Content)"
    if ($Level -eq "DEBUG") { Write-Host $log -ForegroundColor Black -BackgroundColor White }
    elseif ($Level -eq "NOTICE") { Write-Host $log -ForegroundColor Cyan }
    elseif ($Level -eq "INFO") { Write-Host $log -ForegroundColor White }
    elseif ($Level -eq "SUCCESS") { Write-Host $log -ForegroundColor Green }
    elseif ($Level -eq "WARN") { Write-Host $log -ForegroundColor Yellow }
    elseif ($Level -eq "ERROR") { Write-Host $log -ForegroundColor Red }
    elseif ($Level -eq "FATAL") { Write-Host $log -ForegroundColor White -BackgroundColor Red }
    elseif ($Level -eq "DIVIDER") { Write-Host "====================================================================================================" -ForegroundColor Gray }
}

function Read-Config {
    Write-Log "���ڶ�ȡ�����ļ�"
    $config_path = $Workspace + "\config.json"
    if (Test-Path $config_path) {
        $config_string = Get-Content $config_path -Encoding UTF8
        # Win��Դ�������˵�����·��Ĭ��Ϊ��б��\ ���ֱ�Ӹ���ճ����ʵ���ǺϷ���JSON��ʽ �˴����������ݴ�
        Trap { Write-Log "�����ļ�������ȷ�� JSON ��ʽ" ERROR; return $false }
        & { $Script:Config = $config_string.Replace('\\', '/').Replace('\', '/') | ConvertFrom-Json }
        return $true
    }
    else {
        Write-Log "�����ļ������� ���Գ�ʼ��" WARN
        $default_room = New-Object PSObject -Property @{ url = ""; site = "douyu"; room_id = ""; }
        $asx_list = New-Object PSObject -Property @{}
        $config = @{
            after_get = 0;
            asx_list  = $asx_list;
            default   = $default_room;
            player    = "D:/Program/PotPlayer/PotPlayerMini64.exe";
        }
        $config | ConvertTo-Json | Out-File 'config.json' # ��һ����������Ĭ�������ļ�
        $Script:Config = $config # Ӧ�õ�һ�����ɵ������ļ�
        Write-Log "������Ĭ�ϵ������ļ�"
        return $true
    }
}

function Save-Config {
    $Script:Config | ConvertTo-Json | Out-File 'config.json'
}

function Get-LiveInfo {
    param (
        [Parameter(ValueFromPipeline = $true)]
        [String]$LiveUrl
    )
    $pattern = "(?<Site>bilibili|cc\.163|douyu|huya)\b\..*\/\b(?:.*\=)?(?<Room>\w+).*?(?<Exclude>m3u8)?$"
    if ($LiveUrl -match $pattern -and [String]::IsNullOrEmpty($matches.Exclude)) {
        return @{ Site = $matches.Site.Replace(".163", ""); Room = $matches.Room }
    }
    return $null
}

function Test-Input {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [String]$LiveUrl
    )
    $live_info = Get-LiveInfo $LiveUrl
    if ($null -eq $live_info) { return $false }
    return $true
}

function Initialize-Input {
    if ([String]::IsNullOrEmpty($Script:Args)) {
        $clipboard = Get-Clipboard
        if ($clipboard | Test-Input) {
            $Script:LiveInfo = $clipboard | Get-LiveInfo
            Write-Log "�Ӽ��а��ȡ��ֱ���� $($clipboard)" SUCCESS
            return $true
        }
        if (![String]::IsNullOrEmpty($Script:Config.default.url)) {
            if (Test-Input $Script:Config.default.url) {
                Write-Log "������Ĭ��ֱ���� $($Script:Config.default.url)" SUCCESS
                $Script:LiveInfo = $Script:Config.default.url | Get-LiveInfo
                return $true
            }
            Write-Log "������Ĭ��ֱ���� ����֧�ָ�url ��ȷ���Ǵ˽ű�֧�ֵ�ֱ�����ַ" WARN
        }
        if (![String]::IsNullOrEmpty($Script:Config.default.room_id)) {
            $Script:LiveInfo.Room = $Script:Config.default.room_id
            Write-Log "������Ĭ��ֱ���䷿��� $($Script:LiveInfo.Room)" SUCCESS
            if ($Script:Config.default.site -notmatch "\b(bilibili|cc|douyu|huya)\b") {
                $Script:LiveInfo.Site = "douyu"
                Write-Log "δ��⵽�Ϸ���ֱ��ƽ̨���� ��Ĭ����Ϊ����ֱ�������" WARN
            }
            else {
                $Script:LiveInfo.Site = $Script:Config.default.site
                Write-Log "������Ĭ��ֱ��ƽ̨ $($Script:Config.default.site)" SUCCESS
            }
            return $true
        }
        return $false
    }
    else {
        if ([String]::IsNullOrEmpty($Script:Args[1])) {
            # ��һ������
            if (Test-Input $Script:Args[0]) {
                # ��ֱ����������ַ
                $Script:LiveInfo = $Script:Args[0] | Get-LiveInfo
                Write-Log "��Ӧ��ֱ�����ַ $($Script:Args[0])" SUCCESS
                return $true
            }
            elseif ($Script:Args[0] -match '^(\w+)$') {
                # ��ֱ���䷿���
                $Script:LiveInfo.Room = $Script:Args[0]
                Write-Log "��Ӧ��ֱ���䷿��� $($Script:Args[0])" SUCCESS
                if ($Script:Config.default.site -notmatch "\b(bilibili|cc|douyu|huya)\b") {
                    $Script:LiveInfo.Site = "douyu"
                    Write-Log "δ��⵽�Ϸ���ֱ��ƽ̨���� ��Ĭ����Ϊ����ֱ�������" WARN
                }
                else {
                    $Script:LiveInfo.Site = $Script:Config.default.site
                    Write-Log "������Ĭ��ֱ��ƽ̨ $($Script:Config.default.site)" SUCCESS
                }
                return $true
            }
            return $false
        }
        else {
            # ����������
            if (Test-Path $Script:Args[0]) {
                # ��һ�������ǲ����� �ڶ���������ֱ����
                # TODO �Ƿ�Ҫ����ʱ�����������д��Ĳ�����
                $Script:Config.player = $Script:Args[0] # ������ʱ���� ֱ����ȫ�ֱ�����Ļ� ÿ��ִ���������к���ܻḲ�ǵ�ǰ�������ļ�
                Write-Log "��Ӧ�ò�����·�� $($Script:Args[0])" SUCCESS
                if (Test-Input $Script:Args[1]) {
                    # �ڶ���������ֱ����������ַ
                    $Script:LiveInfo = $Script:Args[1] | Get-LiveInfo
                    Write-Log "��Ӧ��ֱ�����ַ $($Script:Args[1])" SUCCESS
                    return $true
                }
                elseif ($Script:Args[1] -match '^(\w+)$') {
                    # �ڶ���������ֱ���䷿���
                    $Script:LiveInfo.Room = $Script:Args[1]
                    Write-Log "��Ӧ��ֱ���䷿��� $($Script:Args[1])" SUCCESS
                    if ($Script:Config.default.site -notmatch "\b(bilibili|cc|douyu|huya)\b") {
                        $Script:LiveInfo.Site = "douyu"
                        Write-Log "δ��⵽�Ϸ���ֱ��ƽ̨���� ��Ĭ����Ϊ����ֱ�������" WARN
                    }
                    else {
                        $Script:LiveInfo.Site = $Script:Config.default.site
                        Write-Log "������Ĭ��ֱ��ƽ̨ $($Script:Config.default.site)" SUCCESS
                    }
                    return $true
                }
                else {
                    Write-Log "�޷�Ӧ��ֱ�����ַ $($Script:Args[1])" WARN
                    return $false
                }
            }
            else {
                # ��һ��������ֱ���� �ڶ��������ǲ�����
                if (Test-Input $Script:Args[0]) {
                    # ��һ��������ֱ����������ַ
                    $Script:LiveInfo = $Script:Args[0] | Get-LiveInfo
                    Write-Log "��Ӧ��ֱ�����ַ $($Script:Args[0])" SUCCESS
                }
                elseif ($Script:Args[0] -match '^(\w+)$') {
                    # ��һ��������ֱ���䷿���
                    $Script:LiveInfo.Room = $Script:Args[0]
                    Write-Log "��Ӧ��ֱ���䷿��� $($Script:Args[0])" SUCCESS
                    if ($Script:Config.default.site -notmatch "\b(bilibili|cc|douyu|huya)\b") {
                        $Script:LiveInfo.Site = "douyu"
                        Write-Log "δ��⵽�Ϸ���ֱ��ƽ̨���� ��Ĭ����Ϊ����ֱ�������" WARN
                    }
                    else {
                        $Script:LiveInfo.Site = $Script:Config.default.site
                        Write-Log "������Ĭ��ֱ��ƽ̨ $($Script:Config.default.site)" SUCCESS
                    }
                }
                else {
                    # ��ӡ������ָ�����󲿷�
                    if ([String]::IsNullOrEmpty($Script:Args[0])) { $input_args = [String]$Script:Args[0] }
                    else {
                        $input_args = [String]$Script:Args[0]
                        For ($i = 1; $i -lt $Script:Args.Count; $i++) { $input_args += " $($Script:Args[$i])" }
                    }
                    Write-Log "��������Ƿ� > $($input_args)`n[$($Script:Args[0])] �Ȳ���ֱ����Ҳ���ǲ�����" WARN
                    return $false
                }
                if (Test-Path $Script:Args[1]) {
                    # �ڶ����������õ��ǲ�����
                    $Script:Config.player = $Script:Args[1]
                    Write-Log "��Ӧ�ò�����·�� $($Script:Args[1])" SUCCESS
                    return $true
                }
                else {
                    # �ڶ����������ǿ��õĲ�����
                    Write-Log "����Ĳ�����·���Ƿ� $($Script:Args[1])" WARN
                    if (Test-Path $Script:Config.player) {
                        # �������ļ������˿��õĲ�����
                        Write-Log "��ʹ�������ļ����õĲ�����·�� $($Script:Config.player)"
                        return $true
                    }
                    else {
                        # ERROR û�п��õĲ�����
                        return $false
                    }
                }
            }
        }
    }
}

function Get-StreamLink {
    if ($null -eq $Script:LiveInfo.Room) {
        return "û������ֱ���䷿���"
    }
    $URI = @{
        Bilibili = "https://api.live.bilibili.com/xlive/web-room/v1/index/getRoomPlayInfo?room_id=$($Script:LiveInfo.Room)&play_url=1&mask=1&qn=0&platform=web";
        Douyu    = "https://web.sinsyth.com/lxapi/douyujx.x?roomid=$($Script:LiveInfo.Room)";
        Huya     = "https://m.huya.com/$($Script:LiveInfo.Room)";
        CC       = "https://vapi.cc.163.com/video_play_url/$($Script:LiveInfo.Room)?vbrname=blueray";
    }
    $Script:Stream.Streamer = $Script:LiveInfo.Room
    if ($Script:LiveInfo.Site.ToLower() -eq "bilibili") {
        $response = Invoke-WebRequest -URI $URI.Bilibili -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
        if ($response.message -ne 0) {
            return $response.message
        }
        elseif ($response.data.live_status -eq 0) {
            return "Bվֱ����$($Script:LiveInfo.Room)û�п���"
        }
        Write-Log "����ץȡ�ɹ� ��ʼ����ֱ��Դ..."
        $user_info_api = "http://api.bilibili.com/x/space/acc/info?mid=$($response.data.uid)&jsonp=jsonp"
        $streamer_info = Invoke-WebRequest -URI $user_info_api -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
        $Script:Stream.Streamer = $streamer_info.data.name
        $temp_link = "https://cn-hbxy-cmcc-live-01.live-play.acgvideo.com/live-bvc/live_" + ($response.data.play_url.durl[0].url -split "/live_")[1]
        $Script:Stream.Link = ($temp_link -split ".flv?")[0].Replace("_1500", "_1500") + ".m3u8" # ������ĳЩֱ��Դɾ�������Ȼ������
        return $null
    }
    elseif ($Script:LiveInfo.Site.ToLower() -eq "cc") {
        $timestamp_hex = "{0:x}" -f [Int](([DateTime]::Now.ToUniversalTime().Ticks - 621355968000000000) / 10000000).tostring().Substring(0, 10)
        $sid = Invoke-WebRequest -URI "https://vapi.cc.163.com/sid?src=webcc" -UseBasicParsing
        $URI.CC += "&t=$($timestamp_hex)&sid=$($sid)&urs=null&src=webcc_4000&vbrmode=1&secure=1"
        try {
            $response = Invoke-WebRequest -URI $URI.CC -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
        }
        catch {
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $response = $reader.ReadToEnd() | ConvertFrom-Json
        }
        if ($null -ne $response.code) {
            if ($response.code -eq "Gone") {
                return "����CCֱ����$($Script:LiveInfo.Room)û�п���"
            }
            else {
                return "����CCֱ����$($Script:LiveInfo.Room)�Ѿ�����"
            }
        }
        # ����ץȡ�ɹ� ��ʼ����ֱ��Դ...
        Write-Log "����ץȡ�ɹ� ��ʼ����ֱ��Դ..."
        $Script:Stream.Streamer = $Script:LiveInfo.Room #TODO ��ȡ��������
        $Script:Stream.Link = $response.videourl
        return $null
    }
    elseif ($Script:LiveInfo.Site.ToLower() -eq "douyu") {
        $response = Invoke-WebRequest -URI $URI.Douyu -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
        if ($response.state -eq "NO") {
            Write-Log "$($response.info)" DEBUG
            return "����ֱ����$($Script:LiveInfo.Room)û�п���"
        }
        Write-Log "����ץȡ�ɹ� ��ʼ����ֱ��Դ..."
        $Script:Stream.Streamer = $response.Rendata.data.nickname
        # $temptx2play1.douyucdn.cn" + ($response.Rendata.link -split "douyucdn.cn")[1]
        # $Script:Stream.Link =_link = "http:// (($temp_link -split ".flv?")[0] -split "_")[0] + "_4000p.m3u8" # ������ĳЩֱ��Դɾ��������֮���޷����� ���ͳһ����4000p�������Ⱥ�׺
        # �˷��� 2020.7.29 �Ѿ�ʧЧ
        $Script:Stream.Link = $response.Rendata.link
        return $null
    }
    elseif ($Script:LiveInfo.Site.ToLower() -eq "huya") {
        $ContentType = "application/x-www-form-urlencoded"
        $UserAgent = "Mozilla/5.0 (Linux; Android 5.0; SM-G900P Build/LRX21T) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.100 Mobile Safari/537.36"
        $response = Invoke-WebRequest -URI $URI.Huya -UseBasicParsing -ContentType $ContentType -UserAgent $UserAgent | Select-Object -ExpandProperty Content
        # $stat_info = "{" + ((($response -split "STATINFO")[1] -split "{")[1] -split "};")[0] + "}"
        # $temp_link = [regex]::matches($response, "hasvedio: '(.*\.m3u8).*", "IgnoreCase")
        $live_status = (($response -split "totalCount: '")[1] -split "',")[0]
        if ($live_status -eq "") {
            return "����ֱ����$($Script:LiveInfo.Room)û�п���"
        }
        Write-Log "����ץȡ�ɹ� ��ʼ����ֱ��Դ..."
        $Script:Stream.Streamer = (($response -split "ANTHOR_NICK = '")[1] -split "';")[0]
        $Script:Stream.Link = "http://al.rtmp.huya.com/backsrc/" + ((($response -split "hasvedio: '")[1] -split "_")[0] -split "src/")[1] + ".m3u8"
        return $null
    }
}

function Select-StreamLink {
    Set-Clipboard $Script:Stream.Link
    # Write-Log "ֱ��Դ�����ɹ� �Ѹ��Ƶ����а�`n���� $($Choose) �ķ�ʽ����ֱ��Դ`n0����ѯ�� 1ֱ�Ӳ��� 2����asx�ļ� 3ֱ���˳�" DEBUG
    $Choose = $Script:Config.after_get
    if ($Choose -eq 0) {
        $thePrompt = @"
�ɹ���$($Script:Stream.Streamer)ֱ���䣨$($Script:LiveInfo.Site)/$($Script:LiveInfo.Room)����ȡ��ֱ��Դ $($Script:Stream.Link)
ֱ��Դ�Ѿ����Ƶ����а壬ʹ�� Ctrl+V ճ����`n
��ǰԤ��Ĳ�����Ϊ $($Script:Config.player)`n
������ǡ�ֱ��ʹ�ñ��ز���������
�����������.asx�ļ�
�����ȡ������������
"@
        $playConfirm = Get-MsgBox -Title "ֱ��Դ��ȡ�ɹ�" -Prompt $thePrompt -Buttons YesNoCancel -Icon Question
        if ($playConfirm -eq 'Yes') {
            $Choose = 1
        }
        elseif ($playConfirm -eq 'No') {
            $Choose = 2
        }
        elseif ($playConfirm -eq 'Cancel') {
            $Choose = 3
        }
    }
    if ($Choose -eq 1) {
        Write-Log "�����������ز����� $($Script:Config.player)"
        Start-Process $Script:Config.player -Argumentlist $Script:Stream.Link
    }
    elseif ($Choose -eq 2) {
        $asx_content = @"
<asx version=`"3.0`">
    <entry>
        <title>[$($Script:LiveInfo.Site)_$($Script:LiveInfo.Room)]$($Script:Stream.Streamer)��ֱ����</title>
        <ref href="$($Script:Stream.Link)" />
    </entry>
</asx>
"@
        $asx_path = "$($Workspace)\live"
        if (!(Test-Path $asx_path)) {
            New-Item -ItemType Directory -Force -Path $asx_path
        }
        $output_path = "$($asx_path)\$($Script:LiveInfo.Site)_$($Script:LiveInfo.Room).asx"
        Write-Output $asx_content | Out-File -filepath $output_path
        Write-Log "������asx�ļ� $($output_path)" SUCCESS
    }
    elseif ($Choose -eq 3) {
        Write-Log "ѡ���˳�"
    }
}

function Get-AsxList {
    if ($null -ne $Script:Config.asx_list -and ![String]::IsNullOrEmpty($Script:Config.asx_list.PSObject.ToString())) {
        Write-Log "��⵽�����ļ����������Զ���ȡ��ֱ���б�`n��ֱ�Ӱ��� config.json �� asx_list �����õ��б�����asx�ļ�`n�����Ҫ���ô˹����뽫�����ļ��� asx_list ��{}�е�����ɾ��" NOTICE
        # Write-Log "list PSCustomObject Ϊ $($Script:Config.asx_list)" DEBUG
        $asx_content = "<asx version=`"3.0`">`n"
        $onlineStream = ""
        $offlineStream = ""
        foreach ($key in $Script:Config.asx_list.PSObject.Properties.Name) {
            $Script:AsxData[$key] = $Script:Config.asx_list.$key
            # Write-Log "$($key) = $($Script:AsxData[$key])" DEBUG
            $Script:LiveInfo = $Script:AsxData[$key] | Get-LiveInfo
            Write-Log "��ʼ���� $($key)($($Script:AsxData[$key]))..."
            $res = Get-StreamLink
            if ($null -eq $res) {
                $onlineStream += @"
    <entry>
        <title>[$($Script:LiveInfo.Site)_$($Script:LiveInfo.Room)]$($key)</title>
        <ref href="$($Script:Stream.Link)" />
    </entry>`n
"@
            }
            else {
                $offlineStream += @"
    <entry>
        <title>[δ����][$($Script:LiveInfo.Site)_$($Script:LiveInfo.Room)]$($key)</title>
        <ref href="$($Script:AsxData[$key])" />
    </entry>`n
"@
            }
        }
        $asx_content += $onlineStream
        $asx_content += $offlineStream
        $asx_content += "</asx>"
        $asx_path = "$($Workspace)\live"
        if (!(Test-Path $asx_path)) {
            New-Item -ItemType Directory -Force -Path $asx_path
        }
        $output_path = "$($asx_path)\ֱ���б�.asx"
        Write-Output $asx_content | Out-File -filepath $output_path
        Write-Log "������asx�б� $($output_path)" SUCCESS
        exit
    }
}

Write-Log -Level DIVIDER

Write-Log "ֱ��Դ�������� Live Stream-link Source Parsing Tool v$($Version)" NOTICE
Write-Log "Cyanashi �������� $($Updated)" NOTICE
Write-Log "����Դ�� $($Source)" NOTICE
Write-Log "������־ https://ews.ink/develop/Get-Stream-Link" NOTICE

Write-Log -Level DIVIDER

if (Read-Config) {
    Write-Log "�����ļ���ȡ�ɹ�" SUCCESS
}
else {
    Write-Log "��������ֹ" ERROR
    # TODO �Ƿ��������ɺϷ��������ļ�
}

Write-Log -Level DIVIDER

Write-Log "��ǰ�汾��֧�� ���� ���� Bվ ����cc" NOTICE

Get-AsxList

if (-not (Initialize-Input)) {
    do {
        try {
            [ValidatePattern('(?<Site>bilibili|cc\.163|douyu|huya)\b\..*\/\b(?:.*\=)?(?<Room>\w+)')]$Script:Input = Read-Host "��������ȷ��ֱ�����ַ"
            if (Test-Input $Script:Input) {
                $Script:LiveInfo = $Script:Input | Get-LiveInfo
                Write-Log "��ʼ���� $($Script:Input)" SUCCESS
            }
        }
        catch { }
    } until ($?)
}

Write-Log -Level DIVIDER

$res = Get-StreamLink
if ($null -eq $res) {
    Write-Log "��ȡֱ��Դ�ɹ� $($Script:Stream.Link)" SUCCESS
    Select-StreamLink
}
else {
    Write-Log "���Ի�ȡֱ��Դʧ�� $($res) $($Script:Stream.Link)" ERROR
}

Write-Log -Level DIVIDER

# Read-Host "�����ѽ��� ����س����˳�" | Out-Null
exit
