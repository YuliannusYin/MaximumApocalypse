# ============================================================================
# .tres → .json 一次性转换脚本
# 用途：把 data/ 下的 Godot .tres 资源（脚本类绑定 .gd）解析为纯 JSON，
#       输出到 Data/<镜像路径>/<同名>.json，供 C# DataLoader 加载。
# 运行：在项目根目录 maximum-apocalypse/ 下执行
#       powershell -ExecutionPolicy Bypass -File Scripts\Tools\convert_tres_to_json.ps1
# ============================================================================
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ---------------------- 枚举表（int → 名称，序与 C# Enums.cs 一致）----------------------
$EnumTables = @{
    'ScavengeColor'     = @('RED','GREEN','BLUE','NONE')
    'ScavengeCardColor' = @('RED','GREEN','BLUE','GRAY','NONE')
    'TriggerTime'       = @('ON_REVEAL','ON_ENTER','ON_END','ON_ACTION')
    'CharacterCard'     = @('ACTION','EQUIPMENT')
    'ScavengeCardType'  = @('ACTION','EQUIPMENT','ITEM')
    'MonsterPack'       = @('ALIEN','MUTANT','ROBOT','ZOMBIE')
    'MonsterLevel'      = @('NORMAL','ELITE','BOSS')
    'RangeType'         = @('NONE','SHORT','MEDIUM','LONG')
}

# ScavengeCardData.card_type 在 .tres 中存为中文字符串
$ChineseCardType = @{ '行动牌'='ACTION'; '装备牌'='EQUIPMENT'; '物品'='ITEM' }

# ---------------------- 字段类型映射（按 script_class）----------------------
$FieldMaps = @{
    'MapBlockData' = [ordered]@{
        'id'='str'; 'tile_name'='str'; 'spawn_values'='int'; 'scavenge_type'='ScavengeColor';
        'effect_trigger'='TriggerTime[]'; 'effect_script_id'='str[]'; 'description'='str'; 'monster_mark'='int'
    }
    'CharacterCardData' = [ordered]@{
        'id'='str'; 'card_name'='str'; 'owner_character_id'='str'; 'description'='str';
        'effect_script_id'='str'; 'card_type'='CharacterCard'; 'equipment_cost'='int';
        'range_type'='RangeType'; 'action_condition'='str'
    }
    'ScavengeCardData' = [ordered]@{
        'id'='str'; 'card_name'='str'; 'category'='str'; 'color'='ScavengeCardColor';
        'card_type'='ScavengeCardType'; 'equipment_slot'='int'; 'value'='int'; 'effect'='str'; 'effect_script_id'='str'
    }
    'MonsterData' = [ordered]@{
        'id'='str'; 'monster_name'='str'; 'pack'='MonsterPack'; 'rank'='MonsterLevel';
        'max_hp'='int'; 'current_hp'='int'; 'damage'='int'; 'range_type'='RangeType';
        'description'='str'; 'Grab_trigger_id'='str'; 'Passive_id'='str'; 'Destroy_id'='str'
    }
    'MissionData' = [ordered]@{
        'id'='str'; 'mission_name'='str'; 'difficulty'='str'; 'description'='str';
        'objective_text'='str'; 'required_van_fuel'='int'; 'starting_tile_id'='str';
        'initial_setup_rule'='str'; 'tile_manifest'='dict'; 'red_scavenge_pool'='dict';
        'green_scavenge_pool'='dict'; 'blue_scavenge_pool'='dict'; 'special_map_requirements'='str'
    }
    'PlayerData' = [ordered]@{
        'id'='str'; 'character_name'='str'; 'max_hp'='int'; 'current_hp'='int';
        'hunger_level'='int'; 'is_starving'='bool'; 'starving_damage_stage'='int';
        'position'='vec2i'; 'base_stealth'='int'; 'starving_stealth'='int';
        'action_points'='int'; 'poison_tokens'='int'; 'is_stunned'='bool'
    }
}

# ---------------------- 自定义 JSON 序列化（输出干净 UTF-8，中文不转义）----------------------
function ConvertTo-CleanJson($obj, [int]$indent = 0) {
    $pad = ''.PadLeft($indent * 2)
    $childPad = ''.PadLeft(($indent + 1) * 2)
    if ($null -eq $obj) { return 'null' }
    $t = $obj.GetType()
    if ($obj -is [bool]) { return $obj.ToString().ToLower() }
    if ($obj -is [int] -or $obj -is [long]) { return $obj.ToString() }
    if ($obj -is [double] -or $obj -is [single]) { return $obj.ToString() }
    if ($obj -is [string]) {
        $s = $obj -replace '\\','\\' -replace '"','\"' -replace "`r","\r" -replace "`n","\n" -replace "`t","\t"
        return '"' + $s + '"'
    }
    if ($obj -is [System.Collections.IList]) {
        if ($obj.Count -eq 0) { return '[]' }
        $items = @()
        foreach ($e in $obj) { $items += $childPad + (ConvertTo-CleanJson $e ($indent + 1)) }
        return "[`n" + ($items -join ",`n") + "`n" + $pad + "]"
    }
    if ($obj -is [System.Collections.IDictionary]) {
        if ($obj.Count -eq 0) { return '{}' }
        $items = @()
        foreach ($k in $obj.Keys) {
            $keyStr = '"' + ($k.ToString() -replace '"','\"') + '"'
            $items += $childPad + $keyStr + ': ' + (ConvertTo-CleanJson $obj[$k] ($indent + 1))
        }
        return "{`n" + ($items -join ",`n") + "`n" + $pad + "}"
    }
    # fallback: 字符串化
    return '"' + ($obj.ToString() -replace '"','\"') + '"'
}

# ---------------------- 值转换 ----------------------
function Convert-Value([string]$type, [string]$raw) {
    $raw = $raw.Trim()
    if ($type -eq 'str') {
        if ($raw.Length -ge 2 -and $raw[0] -eq '"' -and $raw[$raw.Length-1] -eq '"') {
            $inner = $raw.Substring(1, $raw.Length - 2)
            return ($inner -replace '\\"','"')
        }
        return $raw
    }
    if ($type -eq 'int') {
        if ($raw -match '^-?\d+$') { return [int]$raw }
        return 0
    }
    if ($type -eq 'bool') {
        if ($raw -eq 'true') { return $true }
        if ($raw -eq 'false') { return $false }
        return $false
    }
    if ($type -eq 'vec2i') {
        if ($raw -match 'Vector2i\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)') {
            return @{ x = [int]$Matches[1]; y = [int]$Matches[2] }
        }
        return @{ x = 0; y = 0 }
    }
    if ($type -eq 'dict') {
        $d = [ordered]@{}
        $body = $raw.Trim()
        if ($body.StartsWith('{')) { $body = $body.Substring(1) }
        if ($body.EndsWith('}')) { $body = $body.Substring(0, $body.Length - 1) }
        $pairMatches = [regex]::Matches($body, '"([^"]+)"\s*:\s*(-?\d+)')
        foreach ($pm in $pairMatches) { $d[$pm.Groups[1].Value] = [int]$pm.Groups[2].Value }
        return $d
    }
    if ($type -eq 'str[]') {
        $list = @()
        if ($raw -match 'Array\[\w+\]\(\[(.*)\]\)') {
            $inner = $Matches[1].Trim()
            if ($inner) {
                $strMatches = [regex]::Matches($inner, '"([^"]*)"')
                foreach ($sm in $strMatches) { $list += $sm.Groups[1].Value }
            }
        }
        return , $list
    }
    if ($type.EndsWith('[]')) {
        # 枚举数组，如 TriggerTime[]
        $enumName = $type -replace '\[\]$',''
        $list = @()
        if ($raw -match 'Array\[\w+\]\(\[(.*)\]\)') {
            $inner = $Matches[1].Trim()
            if ($inner) {
                $elems = $inner -split ','
                foreach ($e in $elems) {
                    $e = $e.Trim()
                    if ($e -match '^-?\d+$') {
                        $v = [int]$e
                        $tbl = $EnumTables[$enumName]
                        if ($tbl -and $v -ge 0 -and $v -lt $tbl.Count) { $list += $tbl[$v] }
                    }
                }
            }
        }
        return , $list
    }
    # 标量枚举
    $enumName = $type
    if ($raw.Length -ge 2 -and $raw[0] -eq '"' -and $raw[$raw.Length-1] -eq '"') {
        # 字符串（如 card_type 中文）
        $inner = $raw.Substring(1, $raw.Length - 2)
        if ($enumName -eq 'ScavengeCardType' -and $ChineseCardType.ContainsKey($inner)) { return $ChineseCardType[$inner] }
        return $inner
    }
    if ($raw -match '^-?\d+$') {
        $v = [int]$raw
        $tbl = $EnumTables[$enumName]
        if ($tbl -and $v -ge 0 -and $v -lt $tbl.Count) { return $tbl[$v] }
    }
    return $raw
}

# ---------------------- 解析单个 .tres 到有序哈希表 ----------------------
function Convert-TresFile([string]$path) {
    $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $lines = $text -split "`r?`n"

    # 1. 确定 script_class
    $cls = $null
    foreach ($l in $lines) {
        if ($l -match 'script_class="(\w+)"') { $cls = $Matches[1]; break }
    }
    if (-not $cls) {
        foreach ($l in $lines) {
            if ($l -match 'path="res://(\w+)\.gd"') { $cls = $Matches[1]; break }
        }
    }
    if (-not $cls -or -not $FieldMaps.ContainsKey($cls)) {
        Write-Warning "无法识别 script_class，跳过：$path"
        return $null
    }
    $fieldMap = $FieldMaps[$cls]

    # 2. 定位 [resource] 段
    $startIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '[resource]') { $startIdx = $i + 1; break }
    }
    if ($startIdx -lt 0) { Write-Warning "未找到 [resource] 段：$path"; return $null }

    # 3. 逐行解析，处理多行值
    $result = [ordered]@{}
    $i = $startIdx
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('[') -or $trimmed.StartsWith('metadata/') -or $trimmed.StartsWith('script =')) { $i++; continue }
        if ($line -match '^(\w+)\s*=\s*(.*)$') {
            $key = $Matches[1]
            $val = $Matches[2]
            if (-not $fieldMap.Contains($key)) { $i++; continue }
            $type = $fieldMap[$key]

            # 多行检测
            $fullVal = $val
            $isMultilineStr = ($val.Length -ge 1 -and $val[0] -eq '"' -and -not ($val.Length -ge 2 -and $val[$val.Length-1] -eq '"'))
            $isMultilineDict = ($val.TrimStart().StartsWith('{') -and -not $val.TrimEnd().EndsWith('}'))
            $isMultilineArray = ($val.TrimStart().StartsWith('Array[') -and -not $val.TrimEnd().EndsWith('])'))

            if ($isMultilineStr -or $isMultilineDict -or $isMultilineArray) {
                $acc = $val
                $terminated = $false
                while (-not $terminated -and ($i + 1) -lt $lines.Count) {
                    $i++
                    $acc += "`n" + $lines[$i]
                    if ($isMultilineStr -and $lines[$i].TrimEnd().EndsWith('"')) { $terminated = $true }
                    elseif ($isMultilineDict) {
                        $opens = ($acc -split '\{').Count - 1
                        $closes = ($acc -split '\}').Count - 1
                        if ($closes -ge $opens) { $terminated = $true }
                    }
                    elseif ($isMultilineArray -and $lines[$i].TrimEnd().EndsWith('])')) { $terminated = $true }
                }
                $fullVal = $acc
            }
            $result[$key.ToLower()] = Convert-Value -type $type -raw $fullVal
        }
        $i++
    }
    return $result
}

# ---------------------- 主流程 ----------------------
$root = $PSScriptRoot
$projectRoot = Split-Path -Parent (Split-Path -Parent $root)   # maximum-apocalypse/
$srcDataDir = Join-Path $projectRoot 'data'
$dstDataDir = Join-Path $projectRoot 'Data'

if (-not (Test-Path $srcDataDir)) { Write-Error "源数据目录不存在：$srcDataDir"; exit 1 }
if (-not (Test-Path $dstDataDir)) { New-Item -ItemType Directory -Path $dstDataDir -Force | Out-Null }

$tresFiles = Get-ChildItem -Path $srcDataDir -Recurse -Filter '*.tres'
Write-Host "发现 $($tresFiles.Count) 个 .tres 文件，开始转换..." -ForegroundColor Cyan

$count = 0
$failed = @()
foreach ($f in $tresFiles) {
    try {
        $obj = Convert-TresFile -path $f.FullName
        if ($null -eq $obj) { $failed += $f.FullName; continue }
        # 镜像相对路径
        $rel = $f.FullName.Substring($srcDataDir.Length).TrimStart('\','/')
        $dstPath = Join-Path $dstDataDir ($rel -replace '\.tres$','.json')
        $dstDir = Split-Path -Parent $dstPath
        if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
        $json = ConvertTo-CleanJson $obj 0
        [System.IO.File]::WriteAllText($dstPath, $json, [System.Text.UTF8Encoding]::new($false))
        $count++
    } catch {
        Write-Warning "转换失败：$($f.FullName) -> $($_.Exception.Message)"
        $failed += $f.FullName
    }
}

Write-Host ""
Write-Host "转换完成：成功 $count 个" -ForegroundColor Green
if ($failed.Count -gt 0) {
    Write-Host "失败 $($failed.Count) 个：" -ForegroundColor Red
    foreach ($p in $failed) { Write-Host "  $p" }
}
