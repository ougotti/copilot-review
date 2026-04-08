<#
.SYNOPSIS
    設計書をレビュー観点に基づいてAI（GitHub Models API）で自動レビューし、
    結果MDをレビュー結果フォルダに出力するスクリプト。

.PARAMETER Type
    対象種別: "画面" または "バッチ"
    省略時は画面・バッチ両方を処理する。

.PARAMETER Name
    対象フォルダ名（例: "商品一覧", "在庫補充バッチ"）
    省略時は対象種別の全フォルダを処理する。

.PARAMETER Doc
    対象設計書種別: "機能" / "詳細" / "all"（デフォルト: "all"）

.PARAMETER Model
    使用するモデル名（デフォルト: "gpt-4o-mini"）

.PARAMETER Force
    既にレビュー結果ファイルが存在する場合も上書きする。

.EXAMPLE
    # 全設計書を一括自動レビュー
    .\Invoke-DesignReview.ps1

    # 商品一覧画面のみレビュー
    .\Invoke-DesignReview.ps1 -Type 画面 -Name 商品一覧

    # バッチの詳細設計書のみ上書き再レビュー
    .\Invoke-DesignReview.ps1 -Type バッチ -Doc 詳細 -Force
#>
param(
    [ValidateSet("画面","バッチ","")]
    [string]$Type = "",

    [string]$Name = "",

    [ValidateSet("機能","詳細","all")]
    [string]$Doc = "all",

    [string]$Model = "gpt-4o-mini",

    [switch]$Force
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$ApiEndpoint = "https://models.inference.ai.azure.com/chat/completions"

# --- GitHub Models API 呼び出し関数 ---
function Invoke-AIReview {
    param([string]$Prompt, [string]$ModelName)

    $token = gh auth token 2>$null
    if (-not $token) {
        Write-Error "GitHub CLI 認証トークンが取得できません。'gh auth login' を実行してください。"
        exit 1
    }

    $body = @{
        model      = $ModelName
        messages   = @(@{ role = "user"; content = $Prompt })
        max_tokens = 4000
    } | ConvertTo-Json -Depth 10 -Compress

    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json"
    }

    $response = Invoke-RestMethod -Uri $ApiEndpoint -Method Post `
        -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
    return $response.choices[0].message.content
}

# --- 対象種別リスト ---
$types = if ($Type -eq "") { @("画面","バッチ") } else { @($Type) }

$totalCount   = 0
$successCount = 0
$skipCount    = 0

foreach ($targetType in $types) {
    $typeRoot = Join-Path $Root $targetType

    # 対象フォルダ解決
    $Names = if ($Name -eq "") {
        Get-ChildItem -Path $typeRoot -Directory | Select-Object -ExpandProperty Name
    } else {
        @($Name)
    }

    # 観点ファイル読み込み
    $ReviewCriteria = Join-Path $Root "レビュー観点" "${targetType}設計書_レビュー観点.md"
    if (-not (Test-Path $ReviewCriteria)) {
        Write-Warning "レビュー観点ファイルが見つかりません（スキップ）: $ReviewCriteria"
        continue
    }
    $criteriaContent = Get-Content $ReviewCriteria -Raw -Encoding UTF8

    # 対象設計書リスト
    $docTypes = switch ($Doc) {
        "機能" { @("機能") }
        "詳細" { @("詳細") }
        "all"  { @("機能","詳細") }
    }

    foreach ($targetName in $Names) {
        $DesignDocBase = Join-Path $Root $targetType $targetName
        $OutputBase    = Join-Path $Root "レビュー結果" $targetType $targetName

        if (-not (Test-Path $OutputBase)) {
            New-Item -ItemType Directory -Force -Path $OutputBase | Out-Null
        }

        foreach ($docType in $docTypes) {
            $totalCount++
            $docPath    = Join-Path $DesignDocBase "${docType}設計書.md"
            $outputPath = Join-Path $OutputBase "${docType}設計書レビュー.md"
            $promptPath = Join-Path $OutputBase "${docType}設計書レビュー.prompt.txt"

            if (-not (Test-Path $docPath)) {
                Write-Warning "  設計書が見つかりません（スキップ）: $docPath"
                $skipCount++
                continue
            }

            if ((Test-Path $outputPath) -and -not $Force) {
                Write-Host "  ⏭  スキップ（既存）: $outputPath" -ForegroundColor DarkGray
                Write-Host "     上書きする場合は -Force オプションを付けてください。"
                $skipCount++
                continue
            }

            $docContent = Get-Content $docPath -Raw -Encoding UTF8
            $today      = Get-Date -Format "yyyy-MM-dd"

            # プロンプト生成
            $prompt = @"
あなたは熟練のシステムエンジニアです。
以下の設計書を、指定されたレビュー観点チェックリストに基づいて詳細にレビューしてください。

## レビュー対象
- 種別: ${targetType}
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
  | 対象ファイル | ${targetType}\${targetName}\${docType}設計書.md |
  | レビュー日 | ${today} |
  | レビュー者 | Copilot AI (${Model}) |

- レビュー観点の各セクション・各チェック項目を表形式で列挙し、
  「確認結果」列に ○ / × / △ / N/A を必ず記入する
  （○=問題なし, ×=要修正, △=要確認, N/A=対象外）

- ×（要修正）または △（要確認）の項目には「コメント」列に具体的な指摘内容を記載する

- 最後に「## 総評」セクションを追加し、
  全体的な品質評価と主な指摘事項のサマリーを記述する

- 機能設計書のレビューは観点1〜7を対象とし、8〜13はN/Aとする
- 詳細設計書のレビューは観点8〜13（バッチは8〜14）を対象とし、1〜7はN/Aとする
"@

            # プロンプトをファイル保存（再利用・デバッグ用）
            Set-Content -Path $promptPath -Value $prompt -Encoding UTF8

            Write-Host ""
            Write-Host "▶ レビュー中: ${targetType} > ${targetName} > ${docType}設計書" -ForegroundColor Cyan

            try {
                $reviewResult = Invoke-AIReview -Prompt $prompt -ModelName $Model
                Set-Content -Path $outputPath -Value $reviewResult -Encoding UTF8
                Write-Host "  ✅ 完了: $outputPath" -ForegroundColor Green
                $successCount++
            } catch {
                Write-Host "  ❌ エラー: $_" -ForegroundColor Red
            }
        }
    }
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " レビュー完了サマリー" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " 対象: $totalCount 件"
Write-Host " 成功: $successCount 件" -ForegroundColor Green
Write-Host " スキップ: $skipCount 件" -ForegroundColor DarkGray
Write-Host " 出力先: $(Join-Path $Root 'レビュー結果')" -ForegroundColor Cyan
