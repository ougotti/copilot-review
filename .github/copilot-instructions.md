# Copilot 操作ルール – 設計書レビュー自動化プロジェクト

## プロジェクト概要

このリポジトリは **仮想ECサイトの設計書** を管理し、
GitHub Models API（`gpt-4o-mini`）を使って設計書を自動レビューする仕組みを提供します。

---

## フォルダ構成

```
C:\work\copilot-review\
├── .github\
│   └── copilot-instructions.md   ← このファイル
├── 画面\
│   ├── 商品一覧\
│   │   ├── 機能設計書.md
│   │   └── 詳細設計書.md
│   ├── 商品詳細\
│   ├── カート\
│   ├── 注文確認_決済\
│   └── 注文完了\
├── バッチ\
│   ├── 在庫補充バッチ\
│   └── 売上集計バッチ\
├── レビュー観点\
│   ├── 画面設計書_レビュー観点.md
│   └── バッチ設計書_レビュー観点.md
├── レビュー結果\
│   ├── 画面\{画面名}\{機能|詳細}設計書レビュー.md   ← AI生成
│   └── バッチ\{バッチ名}\{機能|詳細}設計書レビュー.md ← AI生成
└── Invoke-DesignReview.ps1       ← レビュー実行スクリプト
```

---

## 自動レビューのルール

**設計書ファイルを作成・変更した後は、必ず以下を実行してレビュー結果を生成すること。**

### 特定の設計書を更新した場合

```powershell
cd C:\work\copilot-review

# 画面の特定設計書をレビュー（-Force で上書き）
.\Invoke-DesignReview.ps1 -Type 画面 -Name 商品一覧 -Force

# バッチの特定設計書をレビュー
.\Invoke-DesignReview.ps1 -Type バッチ -Name 在庫補充バッチ -Force

# 機能設計書のみ
.\Invoke-DesignReview.ps1 -Type 画面 -Name カート -Doc 機能 -Force
```

### 全設計書を一括レビューする場合

```powershell
.\Invoke-DesignReview.ps1 -Force
```

---

## スクリプトパラメータ一覧

| パラメータ | 説明 | デフォルト |
|------------|------|-----------|
| `-Type` | `画面` または `バッチ`（省略時は両方） | （両方） |
| `-Name` | 対象フォルダ名（省略時は全フォルダ） | （全て） |
| `-Doc` | `機能` / `詳細` / `all` | `all` |
| `-Model` | 使用モデル名 | `gpt-4o-mini` |
| `-Force` | 既存レビュー結果を上書き | off |

---

## GitHub push のルール

レビュー結果を生成・更新したら、以下でコミット＆プッシュする。

```powershell
cd C:\work\copilot-review
git add -A
git commit -m "レビュー結果を更新"
git push
```

---

## 認証

スクリプトは `gh auth token` で GitHub CLIのトークンを取得して API 認証を行います。
`gh auth login` 済みであれば追加の設定は不要です。
