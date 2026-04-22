# 設計書 AI 自動レビュー サンプルプロジェクト

GitHub Copilot SDK と `.venv` 上の Python スクリプトを使って、  
**設計書の作成 → レビュー観点の整備 → AI による自動レビュー** までを一気通貫で行うサンプルです。

---

## 📁 リポジトリ構成

```
copilot-review/
├── 画面/                          # 画面設計書（機能設計書・詳細設計書）
│   ├── 商品一覧/
│   ├── 商品詳細/
│   ├── カート/
│   ├── 注文確認_決済/
│   └── 注文完了/
├── バッチ/                        # バッチ設計書（機能設計書・詳細設計書）
│   ├── 在庫補充バッチ/
│   └── 売上集計バッチ/
├── レビュー観点/                  # レビューチェックリスト
│   ├── 画面設計書_レビュー観点.md
│   └── バッチ設計書_レビュー観点.md
├── レビュー結果/                  # AI が生成したレビュー結果 MD
│   ├── 画面/{画面名}/{機能|詳細}設計書レビュー.md
│   └── バッチ/{バッチ名}/{機能|詳細}設計書レビュー.md
├── .github/
│   └── copilot-instructions.md    # Copilot への操作ルール定義
├── design_review.py               # Python レビュー本体
├── requirements.txt               # .venv 用依存関係
└── Invoke-DesignReview.ps1        # Python 起動ラッパー
```

---

## 🛠️ 構築の流れ

### Step 1 – 設計書の作成

仮想 EC サイトを対象に、以下の設計書を Markdown 形式で作成しました。

| 種別 | 対象 | 設計書種別 |
|------|------|-----------|
| 画面 | 商品一覧 / 商品詳細 / カート / 注文確認_決済 / 注文完了 | 機能設計書・詳細設計書 |
| バッチ | 在庫補充バッチ / 売上集計バッチ | 機能設計書・詳細設計書 |

各設計書には **概要・画面レイアウト・機能一覧・入力項目・画面遷移・業務ルール** などを記載。  
詳細設計書には **処理フロー・API 定義・DB アクセス・エラーハンドリング** を含みます。

---

### Step 2 – レビュー観点チェックリストの作成

設計書種別ごとに、レビュー観点を `レビュー観点/` フォルダへ整備しました。

#### 画面設計書 レビュー観点（13 節）

| 観点グループ | 節 |
|------------|-----|
| 基本情報 / 概要・目的 / 画面レイアウト / 機能一覧 / 入力項目 / 画面遷移 / 業務ルール | 機能設計書（1〜7節） |
| 処理フロー / API 定義 / DB アクセス / エラーハンドリング / セキュリティ / パフォーマンス | 詳細設計書（8〜13節） |

#### バッチ設計書 レビュー観点（14 節）

画面設計書の観点に加え、**スケジュール・再実行設計**（14節）を追加。

各チェック項目の評価は `○ / × / △ / N/A` の 4 段階で記入します。

---

### Step 3 – AI 自動レビューの仕組み

#### 構成図

```
[ユーザー or Copilot]
        │  .\Invoke-DesignReview.ps1 を実行
        ▼
[Invoke-DesignReview.ps1]
        └─ .venv の Python で design_review.py を起動
                ├─ 対象設計書 (.md) を読み込む
                ├─ 対応するレビュー観点 (.md) を読み込む
                ├─ プロンプトを生成
                ├─ GitHub Copilot SDK に送信
                └─ レビュー結果を レビュー結果/ に保存
```

#### スクリプトの使い方

```powershell
# 全設計書を一括レビュー（新規のみ）
.\Invoke-DesignReview.ps1

# 特定の画面だけレビュー
.\Invoke-DesignReview.ps1 -Type 画面 -Name 商品一覧

# 既存レビュー結果を上書きして再レビュー
.\Invoke-DesignReview.ps1 -Force

# バッチの詳細設計書のみ
.\Invoke-DesignReview.ps1 -Type バッチ -Doc 詳細 -Force
```

| パラメータ | 説明 | デフォルト |
|------------|------|-----------|
| `-Type` | `画面` または `バッチ`（省略時は両方） | 両方 |
| `-Name` | 対象フォルダ名（省略時は全フォルダ） | 全て |
| `-Doc` | `機能` / `詳細` / `all` | `all` |
| `-Model` | 使用モデル名 | Copilot の既定値 |
| `-Force` | 既存ファイルを上書き | off |

#### レビュー結果の形式

```markdown
# レビュー結果 – 商品一覧 機能設計書

| 項目 | 内容 |
|------|------|
| 対象ファイル | 画面\商品一覧\機能設計書.md |
| レビュー日   | 2026-04-08 |
| レビュー者   | Copilot AI (GitHub Copilot SDK) |

## 1. 基本情報

| No  | 観点 | 確認結果 | コメント |
|-----|------|----------|----------|
| 1-1 | 画面ID・画面名・作成日・バージョンが記載されているか | ○ | |
...

## 総評

全体的に...（AIによる総合評価）
```

---

### Step 4 – Copilot との連携

`.github/copilot-instructions.md` に操作ルールを定義することで、  
GitHub Copilot CLI に「設計書を更新したからレビューして」と指示するだけで  
スクリプトが自動実行されます。

---

## ⚙️ セットアップ

### 前提条件

- `.venv` が作成済みであること
- `.venv\Scripts\python.exe -m pip install -r requirements.txt` を実行済みであること
- GitHub Copilot が認証済みであること
        - `copilot auth login`
        - または `COPILOT_GITHUB_TOKEN` / `GH_TOKEN` / `GITHUB_TOKEN`
- Windows PowerShell 5.1 以上 または PowerShell 7+

### 手順

```powershell
# 1. リポジトリをクローン
git clone https://github.com/ougotti/copilot-review.git
cd copilot-review

# 2. .venv を作成して依存関係をインストール
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt

# 3. GitHub Copilot を認証
copilot auth login

# 4. 全設計書をレビュー実行
.\Invoke-DesignReview.ps1

# 5. 結果を GitHub に push
git add -A
git commit -m "レビュー結果を追加"
git push
```

---

## 📝 利用モデル

モデルは GitHub Copilot SDK 側で解決されます。

- `-Model` を指定した場合はそのモデルを利用
- 未指定の場合は Copilot CLI または `GITHUB_COPILOT_MODEL` の既定値を利用

例:

```powershell
.\Invoke-DesignReview.ps1 -Model gpt-5 -Force
.\Invoke-DesignReview.ps1 -Model claude-sonnet-4 -Force
```

---

## 🔗 関連リンク

- [GitHub Copilot SDK](https://github.com/github/copilot-sdk)
- [GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-cli)
