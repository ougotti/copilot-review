---
name: design-review
description: "Use when: automatically reviewing design documents (functional/detailed) against predefined design review criteria. Generates comprehensive review results with AI-powered analysis using GitHub Copilot SDK in a Python .venv environment. Supports screen and batch design documents."
---

# 設計書自動レビュー SKILL

## 概要

このスキルは、設計書（機能設計書・詳細設計書）を **レビュー観点チェックリスト** に基づいて自動レビューし、
GitHub Copilot SDK による詳細なレビュー結果を markdown 形式で生成します。

**対応する設計書種別:**
- 画面設計書（機能・詳細）
- バッチ設計書（機能・詳細）

---

## 使用条件・前提

・ **Python `.venv`** が作成済み  
  ✅ `.venv\Scripts\python.exe -m pip install -r requirements.txt` を実行

・ **GitHub Copilot の認証** が完了済み  
  ✅ `copilot auth login` または `COPILOT_GITHUB_TOKEN` / `GH_TOKEN` / `GITHUB_TOKEN`

・ **PowerShell 5.1+** または PowerShell Core がインストール済み

・ **レビュー観点ファイル** が以下に存在
  - `レビュー観点/画面設計書_レビュー観点.md`
  - `レビュー観点/バッチ設計書_レビュー観点.md`

・ **設計書ファイル** が以下構成で存在
  ```
  画面/{画面名}/{機能|詳細}設計書.md
  バッチ/{バッチ名}/{機能|詳細}設計書.md
  ```

---

## ワークフロー

### Phase 1: 対象設計書の特定

1. 設計書の種別（画面・バッチ）を確認
2. 対象フォルダ名（画面名・バッチ名）を確認
3. 対象設計書タイプ（機能・詳細・all）を確認
4. 対象設計書ファイルが存在するか検証

### Phase 2: レビュー観点の読み込み

1. 対応するレビュー観点ファイルを読み込み
2. チェックリストの全項目を構文解析
3. 機能設計書・詳細設計書の対応する観点を抽出

### Phase 3: Copilot レビュープロンプト生成

1. 設計書の全文を読み込み  
2. レビュー観点と設計書を含む詳細なプロンプトを構成
3. GitHub Copilot SDK で AI レビュー実行
  - 実行環境: `.venv` 上の Python
  - モデル: `-Model` または `GITHUB_COPILOT_MODEL`、未指定時は Copilot 既定値

### Phase 4: レビュー結果の生成・保存

1. AI出力を markdown 形式で整形（既に整形されている想定）
2. 以下の形式で保存
   ```
   レビュー結果/{種別}/{対象名}/{機能|詳細}設計書レビュー.md
   ```
3. レビュー結果に以下を含む
   - ファイル情報（対象ファイル、レビュー日、レビュー者）
   - 各チェック項目の評価（○/×/△/N/A）
   - 指摘事項（具体的なコメント）
   - 総評セクション

---

## パラメータ

| パラメータ | 型 | デフォルト | 説明 |
|-----------|-----|---------|------|
| `type` | string | `""` | 設計書種別: `"画面"` / `"バッチ"` / `""` (両方) |
| `name` | string | `""` | 対象フォルダ名: `""` (全て) / `"商品一覧"` など |
| `doc` | string | `"all"` | 設計書タイプ: `"機能"` / `"詳細"` / `"all"` |
| `model` | string | `""` | 使用AI モデル。空なら Copilot 既定値 |
| `force` | boolean | `false` | 既存レビュー結果を上書き |

---

## 実行手順

### 1. スクリプト実行 (ターミナル)

```powershell
# セッションの場所を確認
cd C:\work\copilot-review

# .venv 依存関係をインストール
.\.venv\Scripts\python.exe -m pip install -r requirements.txt

# Copilot 認証
copilot auth login

# 全設計書を自動レビュー
.\Invoke-DesignReview.ps1

# 特定の画面のみレビュー
.\Invoke-DesignReview.ps1 -Type 画面 -Name 商品一覧

# バッチの詳細設計書のみ、上書き再レビュー
.\Invoke-DesignReview.ps1 -Type バッチ -Doc 詳細 -Force

# 特定モデル指定でレビュー
.\Invoke-DesignReview.ps1 -Type 画面 -Model gpt-5 -Force
```

### 2. Copilot Chat を使用する場合

このスキルが Copilot Chat に統合されている場合：

```
/design-review 商品一覧 機能設計書
```

または

```
設計書 "商品一覧" をレビューして
```

---

## 出力形式

### ファイル構造

```
レビュー結果/
├── 画面/
│   ├── 商品一覧/
│   │   ├── 機能設計書レビュー.md
│   │   └── 詳細設計書レビュー.md
│   ├── 商品詳細/
│   ...
└── バッチ/
    ├── 在庫補充バッチ/
    │   ├── 機能設計書レビュー.md
    │   └── 詳細設計書レビュー.md
    ...
```

### マークダウン内容例

```markdown
# レビュー結果 – 商品一覧 機能設計書
| 項目 | 内容 |
|------|------|
| 対象ファイル | 画面\商品一覧\機能設計書.md |
| レビュー日 | 2026-04-09 |
| レビュー者 | Copilot AI (GitHub Copilot SDK) |

## 【機能設計書】チェックリスト

### 1. 基本情報
| No | 観点 | 確認結果 | コメント |
|----|------|----------|----------|
| 1-1 | 画面ID・画面名・作成日・バージョンが記載されているか | ○ | 問題なし |
| 1-2 | バージョン管理されており、変更履歴が追跡可能か | × | 変更履歴が記載されていないため、バージョン管理が不十分です。 |

...

## 総評
【品質評価】: 要修正  
【主な指摘】: バージョン管理、レスポンシブ対応の検討が必要です。
```

---

## 機能設計書 vs 詳細設計書

### 機能設計書 (観点 1-7)
- 基本情報
- 概要・目的
- 画面レイアウト
- 機能一覧
- 入力項目
- 画面遷移
- 業務ルール

### 詳細設計書 (観点 8-13 / 8-14 for バッチ)
- DB/ API 仕様
- 画面項目の詳細
- 相互作用・通信仕様
- 状態管理
- エラーハンドリング
- バッチ特有: 実行パラメータ等

---

## トラブルシューティング

### 認証エラー (GitHub Copilot)

**症状**: `Not authenticated` または `Failed to start GitHub Copilot client`

**対処**:
```powershell
# GitHub Copilot を認証
copilot auth login

# 確認
copilot auth status

# 再実行
.\Invoke-DesignReview.ps1 -Force
```

### SDK / API 呼び出しエラー

**症状**: `RateLimitReached` または SDK 実行エラー

**対処**:
- レート制限時はスクリプトが自動で待機して再試行する
- それでも失敗する場合は対象を分割して実行する
- モデルを変更試行: `-Model gpt-5` または `-Model claude-sonnet-4`

### レビュー結果ファイルが作成されない

**症状**: `レビュー完了サマリー` で success_count が 0

**対処**:
1. 設計書ファイルが存在するか確認
   ```powershell
   ls 画面\商品一覧\機能設計書.md
   ```

2. レビュー観点ファイルが存在するか確認
   ```powershell
   ls レビュー観点\画面設計書_レビュー観点.md
   ```

3. PowerShell エラーログを確認
   ```powershell
   .\Invoke-DesignReview.ps1 -Force 2>&1 | Tee-Object -FilePath debug.log
   ```

---

## 推奨される運用フロー

1. **設計書作成・変更後**
   ```powershell
   .\Invoke-DesignReview.ps1 -Type 画面 -Name {画面名} -Force
   ```

2. **レビュー&修正イテレーション**
   - AI レビュー結果を確認
   - 設計書を修正
   - 再度レビュー実行

3. **確定時**
   ```powershell
   git add レビュー結果\
   git commit -m "レビュー結果を更新: {画面名}/{バッチ名}"
   git push
   ```

---

## 出力例記録パス

- 実行ログ: ターミナル出力（`レビュー中...`, `✅ 完了:` など）
- 結果ファイル: `レビュー結果/{種別}/{対象名}/{設計書タイプ}設計書レビュー.md`
- エラー詳細: PowerShell のターミナル出力

---

## 制限事項・既知の問題

・ **単一 API 呼び出しのため時間がかかる可能性**  
  → 大型ドキュメント（5000+ 文字）はレスポンス遅延の可能性あり

・ **GitHub Copilot / SDK の利用制限**  
  → レート制限により待機や再実行が必要になることがある

・ **AI 生成の再現性**  
  → 同じ入力でも AIレビュー結果が微妙に変わる可能性あり

・ **日本語特有の判定課題**  
  → 曖昧な日本語表現の検出精度は 100% ではない

---

## 参考リンク

・ GitHub Copilot SDK ドキュメント  
  https://github.com/github/copilot-sdk

・ プロジェクトレポジトリ  
  https://github.com/ougotti/copilot-review

・ Copilot Instructions ドキュメント  
  `.github/copilot-instructions.md`
