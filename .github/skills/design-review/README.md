# 設計書自動レビュー SKILL

このフォルダは、GitHub Copilot Chat における **設計書レビュー自動化** SKILL の定義です。

## フォルダ構成

```
.github/skills/design-review/
├── SKILL.md                      # SKILL 定義ドキュメント
├── Get-ReviewChecklist.ps1      # レビュー観点チェックリスト表示ツール
├── Get-ReviewSummary.ps1        # レビュー結果統計表示ツール
└── README.md                     # このファイル
```

## SKILL のロード

このスキルは自動的に GitHub Copilot Chat に認識されます。

**Copilot Chat での使用例:**

```
/design-review 商品一覧 機能設計書
```

または自然言語で：

```
商品一覧の機能設計書をレビューして
```

## ヘルパースクリプト

### Get-ReviewChecklist.ps1

レビュー対象となるチェック項目を一覧表示します。

**使用例:**
```powershell
cd レビュー結果
.\Get-ReviewChecklist.ps1 -Type 画面 -DocType 機能

.\Get-ReviewChecklist.ps1 -Type バッチ -DocType 詳細
```

**出力:**
- 全チェック項目の一覧
- 各項目の観点説明

### Get-ReviewSummary.ps1

既に生成されたレビュー結果から統計情報を集計・表示します。

**使用例:**
```powershell
.\Get-ReviewSummary.ps1

.\Get-ReviewSummary.ps1 -Type 画面

.\Get-ReviewSummary.ps1 -Name 商品一覧
```

**出力:**
- 各設計書ごと問題数（○/×/△/N/A）
- 全体統計
- 品質評価

## 実行フロー

### 1. レビューを実行

```powershell
cd C:\work\copilot-review

# 特定の設計書をレビュー
.\Invoke-DesignReview.ps1 -Type 画面 -Name 商品一覧
```

### 2. チェックリストを確認（オプション）

```powershell
cd .github/skills/design-review

.\Get-ReviewChecklist.ps1 -Type 画面 -DocType 機能
```

### 3. レビュー結果をチェック

```powershell
cd レビュー結果

# 結果を統計的に確認
.\../.github/skills/design-review/Get-ReviewSummary.ps1
```

### 4. 結果をGit コミット

```powershell
git add レビュー結果/
git commit -m "レビュー結果を更新: 商品一覧機能設計書"
git push
```

## トラブルシューティング

### スクリプトが実行できない

```powershell
# PowerShell 実行ポリシーを確認・変更
Get-ExecutionPolicy

# 現在のセッションのみ許可
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### GitHub Copilot 認証エラー

```powershell
copilot auth login
copilot auth status
```

## 詳細

SKILL の詳細は [SKILL.md](./SKILL.md) を参照してください。
