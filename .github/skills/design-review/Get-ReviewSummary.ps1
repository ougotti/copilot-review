#!/usr/bin/env pwsh
<#
.SYNOPSIS
    レビュー結果の統計情報を表示
    
.DESCRIPTION
    生成済みのレビュー結果ファイルを解析し、
    全体的な品質メトリクス（○/×/△ の分布）を表示します。
    
.PARAMETER Type
    "画面" / "バッチ" / ""（両方）
    
.PARAMETER Name
    特定の対象名でフィルタ
    
.EXAMPLE
    .\Get-ReviewSummary.ps1
    
    .\Get-ReviewSummary.ps1 -Type 画面
    
    .\Get-ReviewSummary.ps1 -Name 商品一覧
#>

param(
    [ValidateSet("画面", "バッチ", "")]
    [string]$Type = "",
    
    [string]$Name = ""
)

$resultRoot = "../レビュー結果"

if (-not (Test-Path $resultRoot)) {
    Write-Error "レビュー結果フォルダが見つかりません: $resultRoot"
    exit 1
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  レビュー結果 統計サマリー" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$types = if ($Type -eq "") { @("画面", "バッチ") } else { @($Type) }
$totalStats = @{ "○" = 0; "×" = 0; "△" = 0; "N/A" = 0 }
$fileCount = 0

foreach ($t in $types) {
    $typeRoot = Join-Path $resultRoot $t
    if (-not (Test-Path $typeRoot)) { continue }
    
    Write-Host "【 $t 】" -ForegroundColor Yellow
    
    $dirs = Get-ChildItem -Path $typeRoot -Directory
    
    foreach ($dir in $dirs) {
        if ($Name -and $Name -ne $dir.Name) { continue }
        
        $files = Get-ChildItem -Path $dir.FullName -Filter "*レビュー.md"
        
        foreach ($file in $files) {
            $fileCount++
            $content = Get-Content $file.FullName -Raw -Encoding UTF8
            
            # 結果の ○/×/△/N/A を集計
            $okCount = ([regex]::Matches($content, "\| ○ \|") | Measure-Object).Count
            $ngCount = ([regex]::Matches($content, "\| × \|") | Measure-Object).Count
            $checkCount = ([regex]::Matches($content, "\| △ \|") | Measure-Object).Count
            $naCount = ([regex]::Matches($content, "\| N/A \|") | Measure-Object).Count
            
            $totalStats["○"] += $okCount
            $totalStats["×"] += $ngCount
            $totalStats["△"] += $checkCount
            $totalStats["N/A"] += $naCount
            
            $status = if ($ngCount -gt 0) { "⚠️  要修正" } elseif ($checkCount -gt 0) { "⚡ 要確認" } else { "✅ OK" }
            
            Write-Host "  $status  $($dir.Name) / $($file.BaseName)" -ForegroundColor $(
                if ($ngCount -gt 0) { 'Red' } elseif ($checkCount -gt 0) { 'Yellow' } else { 'Green' }
            )
            Write-Host "    ○: $okCount, ×: $ngCount, △: $checkCount, N/A: $naCount" -ForegroundColor DarkGray
        }
    }
    
    Write-Host ""
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "【 全体統計 】" -ForegroundColor Cyan

$totalChecks = @($totalStats.Values | Measure-Object -Sum).Sum

if ($totalChecks -gt 0) {
    Write-Host ""
    Write-Host "  総チェック件数: $totalChecks"
    Write-Host "  ✅ 問題なし (○): $($totalStats["○"]) $(($totalStats["○"]/$totalChecks*100).ToString('F1'))%"
    Write-Host "  ⚠️  要修正 (×): $($totalStats["×"]) $(($totalStats["×"]/$totalChecks*100).ToString('F1'))%"
    Write-Host "  ⚡ 要確認 (△): $($totalStats["△"]) $(($totalStats["△"]/$totalChecks*100).ToString('F1'))%"
    Write-Host "  N/A: $($totalStats["N/A"])"
    Write-Host ""
    
    # 品質情報
    $quality = if ($totalStats["×"] -eq 0 -and $totalStats["△"] -le ($totalChecks * 0.1)) {
        "優: 高品質 📈"
    } elseif ($totalStats["×"] -le ($totalChecks * 0.1)) {
        "良: 修正箇所少ない"
    } else {
        "要改善: 修正が必要 ⚠️"
    }
    
    Write-Host "  品質評価: $quality" -ForegroundColor $(
        if ($quality -match "優") { 'Green' } elseif ($quality -match "良") { 'Yellow' } else { 'Red' }
    )
} else {
    Write-Host "  (レビュー結果ファイルが見つかりません)" -ForegroundColor DarkGray
}

Write-Host ""
