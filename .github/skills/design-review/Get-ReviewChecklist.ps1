#!/usr/bin/env pwsh
<#
.SYNOPSIS
    設計書レビューチェックリスト – クイックリファレンス
    
.DESCRIPTION
    レビュー対象の設計書タイプあたり、どのような観点でチェックされるかを
    ターミナルに見やすく出力します。
    
.PARAMETER Type
    "画面" または "バッチ"
    
.PARAMETER DocType
    "機能" または "詳細"
    
.EXAMPLE
    .\Get-ReviewChecklist.ps1 -Type 画面 -DocType 機能
    
    .\Get-ReviewChecklist.ps1 -Type バッチ
#>

param(
    [ValidateSet("画面", "バッチ")]
    [string]$Type = "画面",
    
    [ValidateSet("機能", "詳細", "")]
    [string]$DocType = ""
)

$criteriaFile = if ($Type -eq "画面") {
    "../レビュー観点/画面設計書_レビュー観点.md"
} else {
    "../レビュー観点/バッチ設計書_レビュー観点.md"
}

if (-not (Test-Path $criteriaFile)) {
    Write-Error "レビュー観点ファイルが見つかりません: $criteriaFile"
    exit 1
}

$content = Get-Content $criteriaFile -Raw -Encoding UTF8

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  レビュー観点チェックリスト – $Type 設計書" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($DocType) {
    # 特定の設計書タイプのセクションのみ抽出
    $pattern = "### \d+ \. [\s\S]*?(?=### \d+|$)"
    $matches = [regex]::Matches($content, $pattern)
    
    Write-Host "【${DocType}設計書】チェックリスト" -ForegroundColor Green
    Write-Host ""
    
    if ($DocType -eq "機能") {
        # 観点 1-7 を抽出
        $section = [regex]::Match($content, "## 【機能設計書】チェックリスト[\s\S]*?(?=## 【詳細設計書|$)").Value
    } else {
        # 観点 8 以降を抽出
        $section = [regex]::Match($content, "## 【詳細設計書】チェックリスト[\s\S]*?$").Value
    }
    
    if ($section) {
        Write-Host $section
    }
} else {
    # 全観点を表示
    Write-Host $content
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "凡例: ○ = 問題なし, × = 要修正, △ = 要確認, N/A = 対象外" -ForegroundColor DarkGray
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""
