<#
.SYNOPSIS
    設計書をレビュー観点に基づいてAIレビューし、結果MDを出力するスクリプト。
    実行すると各設計書のプロンプトファイルを生成し、標準出力にも出力する。
    Copilot CLI などのAIツールからこのプロンプトを利用してレビューを実施する。

.PARAMETER Type
    対象種別: "画面" または "バッチ"

.PARAMETER Name
    対象フォルダ名（例: "商品一覧", "在庫補充バッチ"）
    省略時は対象種別の全フォルダを処理する。

.PARAMETER Doc
    対象設計書種別: "機能" / "詳細" / "all"（デフォルト: "all"）

.PARAMETER OutputResult
    レビュー結果MDを直接書き込む場合は、結果テキストをこのパラメータで渡す。
    （Copilot CLI が自動レビューした内容を書き込む用途）

.EXAMPLE
    # プロンプト生成（Copilot CLI に貼り付けてレビューを依頼）
    .\Invoke-DesignReview.ps1 -Type 画面 -Name 商品一覧

    # 全バッチを一括プロンプト生成
    .\Invoke-DesignReview.ps1 -Type バッチ

    # 特定ファイルのレビュー結果を書き込む（スクリプト内部から呼ばれる想定）
    .\Invoke-DesignReview.ps1 -Type 画面 -Name 商品一覧 -Doc 機能 -OutputResult $reviewText
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet("画面","バッチ")]
    [string]$Type,

    [string]$Name = "",

    [ValidateSet("機能","詳細","all")]
    [string]$Doc = "all",

    [string]$OutputResult = ""
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

# --- 対象フォルダ解決 ---
$typeRoot = Join-Path $Root $Type
if ($Name -eq "") {
    $Names = Get-ChildItem -Path $typeRoot -Directory | Select-Object -ExpandProperty Name
} else {
    $Names = @($Name)
}

# --- 観点ファイルの読み込み ---
$ReviewCriteria = Join-Path $Root "レビュー観点" "${Type}設計書_レビュー観点.md"
if (-not (Test-Path $ReviewCriteria)) {
    Write-Error "レビュー観点ファイルが見つかりません: $ReviewCriteria"
    exit 1
}
$criteriaContent = Get-Content $ReviewCriteria -Raw -Encoding UTF8

# --- 対象設計書リスト ---
$docTypes = switch ($Doc) {
    "機能" { @("機能") }
    "詳細" { @("詳細") }
    "all"  { @("機能","詳細") }
}

foreach ($targetName in $Names) {
    $DesignDocBase = Join-Path $Root $Type $targetName
    $OutputBase    = Join-Path $Root "レビュー結果" $Type $targetName

    # 出力フォルダ作成
    if (-not (Test-Path $OutputBase)) {
        New-Item -ItemType Directory -Force -Path $OutputBase | Out-Null
    }

    foreach ($docType in $docTypes) {
        $docPath    = Join-Path $DesignDocBase "${docType}設計書.md"
        $outputPath = Join-Path $OutputBase "${docType}設計書レビュー.md"

        if (-not (Test-Path $docPath)) {
            Write-Warning "設計書が見つかりません（スキップ）: $docPath"
            continue
        }

        # --- OutputResult が渡された場合は書き込んで終了 ---
        if ($OutputResult -ne "") {
            Set-Content -Path $outputPath -Value $OutputResult -Encoding UTF8
            Write-Host "✓ レビュー結果を書き込みました: $outputPath" -ForegroundColor Green
            continue
        }

        $docContent = Get-Content $docPath -Raw -Encoding UTF8
        $today      = Get-Date -Format "yyyy-MM-dd"

        # --- プロンプト生成 ---
        $prompt = @"
あなたは熟練のシステムエンジニアです。
以下の設計書を、指定されたレビュー観点チェックリストに基づいて詳細にレビューしてください。

## レビュー対象
- 種別: ${Type}
- 対象: ${targetName}
- 設計書: ${docType}設計書

## 設計書本文
---
$docContent
---

## レビュー観点チェックリスト
---
$criteriaContent
---

## 出力指示
以下のMarkdown形式で出力してください。

- 出力の先頭は下記ヘッダーから始める:
  # レビュー結果 – ${targetName} ${docType}設計書
  | 項目 | 内容 |
  |------|------|
  | 対象ファイル | ${Type}\${targetName}\${docType}設計書.md |
  | レビュー日 | ${today} |
  | レビュー者 | Copilot AI |

- レビュー観点の各セクション・各チェック項目を表形式で列挙し、
  「確認結果」列に ○ / × / △ / N/A を必ず記入する
  （○=問題なし, ×=要修正, △=要確認, N/A=対象外）

- ×（要修正）または △（要確認）の項目には「コメント」列に具体的な指摘内容を記載する

- 最後に「## 総評」セクションを追加し、
  全体的な品質評価と主な指摘事項のサマリーを記述する
"@

        # プロンプトをファイルに保存
        $promptPath = Join-Path $OutputBase "${docType}設計書レビュー.prompt.txt"
        Set-Content -Path $promptPath -Value $prompt -Encoding UTF8

        Write-Host ""
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host "▶ レビュープロンプト生成: ${Type} > ${targetName} > ${docType}設計書" -ForegroundColor Cyan
        Write-Host "  プロンプトファイル: $promptPath" -ForegroundColor Gray
        Write-Host "  結果出力先:         $outputPath" -ForegroundColor Gray
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host $prompt
    }
}

Write-Host ""
Write-Host "✅ 完了。レビュー結果フォルダ: $(Join-Path $Root 'レビュー結果')" -ForegroundColor Green
