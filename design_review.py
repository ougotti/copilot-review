from __future__ import annotations

import argparse
import asyncio
import os
import re
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path

from agent_framework.github import GitHubCopilotAgent
from dotenv import load_dotenv


ROOT = Path(__file__).resolve().parent
RETRY_LIMIT = 5
DEFAULT_TIMEOUT_SECONDS = 180.0
RATE_LIMIT_PATTERN = re.compile(r"Please wait\s+(\d+)\s+seconds", re.IGNORECASE)


@dataclass(frozen=True)
class ReviewTask:
    target_type: str
    target_name: str
    doc_type: str
    doc_path: Path
    output_path: Path
    criteria_path: Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="GitHub Copilot SDK を使って設計書レビュー結果を生成する")
    parser.add_argument("--type", dest="target_type", choices=["画面", "バッチ"], default="")
    parser.add_argument("--name", default="")
    parser.add_argument("--doc", choices=["機能", "詳細", "all"], default="all")
    parser.add_argument("--model", default="")
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def list_target_types(target_type: str) -> list[str]:
    return [target_type] if target_type else ["画面", "バッチ"]


def list_doc_types(doc: str) -> list[str]:
    if doc == "all":
        return ["機能", "詳細"]
    return [doc]


def list_target_names(target_root: Path, selected_name: str) -> list[str]:
    if selected_name:
        return [selected_name]
    return sorted(path.name for path in target_root.iterdir() if path.is_dir())


def reviewer_label(model: str) -> str:
    if model:
        return f"Copilot AI ({model} via GitHub Copilot SDK)"
    return "Copilot AI (GitHub Copilot SDK)"


def build_prompt(task: ReviewTask, doc_content: str, criteria_content: str, model: str) -> str:
    review_date = date.today().isoformat()
    return f"""
あなたは熟練のシステムエンジニアです。
以下の設計書を、指定されたレビュー観点チェックリストに基づいて詳細にレビューしてください。

## レビュー対象
- 種別: {task.target_type}
- 対象: {task.target_name}
- 設計書: {task.doc_type}設計書

## 設計書本文
---
{doc_content}
---

## レビュー観点チェックリスト
---
{criteria_content}
---

## 出力指示
以下の Markdown 形式で出力してください。

- 出力は Markdown 本文のみとし、前置き・後書き・コードブロックは付けないこと
- 出力の先頭は下記ヘッダーから始める:
  # レビュー結果 – {task.target_name} {task.doc_type}設計書
  | 項目 | 内容 |
  |------|------|
    | 対象ファイル | {task.target_type}\\{task.target_name}\\{task.doc_type}設計書.md |
  | レビュー日 | {review_date} |
  | レビュー者 | {reviewer_label(model)} |

- レビュー観点の各セクション・各チェック項目を表形式で列挙し、
  「確認結果」列に ○ / × / △ / N/A を必ず記入する
  （○=問題なし, ×=要修正, △=要確認, N/A=対象外）

- ×（要修正）または △（要確認）の項目には「コメント」列に具体的な指摘内容を記載する

- 最後に「## 総評」セクションを追加し、
  全体的な品質評価と主な指摘事項のサマリーを記述する

- 機能設計書のレビューは観点 1〜7 を対象とし、8 以降は N/A とする
- 詳細設計書のレビューは画面は観点 8〜13、バッチは観点 8〜14 を対象とし、1〜7 は N/A とする
- 回答は日本語で行うこと
""".strip()


def extract_response_text(response: object) -> str:
    text = getattr(response, "text", None)
    if isinstance(text, str) and text.strip():
        return text.strip()

    messages = getattr(response, "messages", None)
    if not messages:
        return str(response).strip()

    chunks: list[str] = []
    for message in messages:
        message_text = getattr(message, "text", None)
        if isinstance(message_text, str) and message_text.strip():
            chunks.append(message_text.strip())
            continue

        contents = getattr(message, "contents", None) or []
        for content in contents:
            content_text = getattr(content, "text", None)
            if isinstance(content_text, str) and content_text.strip():
                chunks.append(content_text.strip())

    if chunks:
        return "\n\n".join(chunks).strip()

    return str(response).strip()


def parse_rate_limit_wait_seconds(message: str) -> int | None:
    if "RateLimitReached" not in message and "rate limit" not in message.lower():
        return None

    match = RATE_LIMIT_PATTERN.search(message)
    if match:
        return int(match.group(1))
    return 60


async def request_review(agent: GitHubCopilotAgent, prompt: str, model: str) -> str:
    options: dict[str, object] = {"timeout": DEFAULT_TIMEOUT_SECONDS}
    if model:
        options["model"] = model

    for attempt in range(1, RETRY_LIMIT + 1):
        try:
            response = await agent.run(prompt, options=options)
            text = extract_response_text(response)
            if not text:
                raise RuntimeError("GitHub Copilot SDK から空の応答が返されました。")
            return text
        except Exception as exc:
            message = str(exc)
            wait_seconds = parse_rate_limit_wait_seconds(message)
            if wait_seconds is not None and attempt < RETRY_LIMIT:
                print(
                    f"  ⏳ API レート制限に到達: {wait_seconds}秒待機して再試行します（{attempt}/{RETRY_LIMIT}）"
                )
                await asyncio.sleep(wait_seconds + 1)
                continue
            raise

    raise RuntimeError("レビューの再試行回数を超えました。")


def iter_review_tasks(args: argparse.Namespace) -> tuple[list[ReviewTask], int]:
    tasks: list[ReviewTask] = []
    skipped = 0

    for target_type in list_target_types(args.target_type):
        target_root = ROOT / target_type
        criteria_path = ROOT / "レビュー観点" / f"{target_type}設計書_レビュー観点.md"
        if not criteria_path.exists():
            print(f"レビュー観点ファイルが見つかりません（スキップ）: {criteria_path}")
            continue

        for target_name in list_target_names(target_root, args.name):
            doc_base = target_root / target_name
            output_base = ROOT / "レビュー結果" / target_type / target_name
            output_base.mkdir(parents=True, exist_ok=True)

            for doc_type in list_doc_types(args.doc):
                doc_path = doc_base / f"{doc_type}設計書.md"
                output_path = output_base / f"{doc_type}設計書レビュー.md"

                if not doc_path.exists():
                    print(f"  設計書が見つかりません（スキップ）: {doc_path}")
                    skipped += 1
                    continue

                if output_path.exists() and not args.force:
                    print(f"  ⏭  スキップ（既存）: {output_path}")
                    print("     上書きする場合は --force オプションを付けてください。")
                    skipped += 1
                    continue

                tasks.append(
                    ReviewTask(
                        target_type=target_type,
                        target_name=target_name,
                        doc_type=doc_type,
                        doc_path=doc_path,
                        output_path=output_path,
                        criteria_path=criteria_path,
                    )
                )

    return tasks, skipped


async def run_reviews(args: argparse.Namespace) -> int:
    load_dotenv()

    tasks, skipped = iter_review_tasks(args)
    total_count = len(tasks) + skipped
    success_count = 0

    default_options: dict[str, object] = {
        "timeout": DEFAULT_TIMEOUT_SECONDS,
        "log_level": os.getenv("GITHUB_COPILOT_LOG_LEVEL", "info"),
    }
    if args.model:
        default_options["model"] = args.model

    agent = GitHubCopilotAgent(
        instructions=(
            "You are a senior systems engineer reviewing Japanese design documents. "
            "Return only the requested markdown review result."
        ),
        default_options=default_options,
    )

    try:
        async with agent:
            for task in tasks:
                doc_content = task.doc_path.read_text(encoding="utf-8")
                criteria_content = task.criteria_path.read_text(encoding="utf-8")
                prompt = build_prompt(task, doc_content, criteria_content, args.model)

                print()
                print(f"▶ レビュー中: {task.target_type} > {task.target_name} > {task.doc_type}設計書")

                try:
                    result = await request_review(agent, prompt, args.model)
                    if not result.endswith("\n"):
                        result += "\n"
                    task.output_path.write_text(result, encoding="utf-8")
                    print(f"  ✅ 完了: {task.output_path}")
                    success_count += 1
                except Exception as exc:
                    print(f"  ❌ エラー: {exc}")
    except Exception as exc:
        print(f"初期化エラー: {exc}")
        print("認証が必要な場合は 'copilot auth login'、または COPILOT_GITHUB_TOKEN / GH_TOKEN / GITHUB_TOKEN を設定してください。")
        return 1

    print()
    print("======================================")
    print(" レビュー完了サマリー")
    print("======================================")
    print(f" 対象: {total_count} 件")
    print(f" 成功: {success_count} 件")
    print(f" スキップ: {skipped} 件")
    print(f" 出力先: {ROOT / 'レビュー結果'}")

    return 0 if success_count == len(tasks) else 1


def main() -> int:
    args = parse_args()
    return asyncio.run(run_reviews(args))


if __name__ == "__main__":
    sys.exit(main())