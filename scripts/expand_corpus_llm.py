#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Expand Chinese and English corpora by calling an online LLM.

Usage examples:
  OPENAI_API_KEY=sk-... \
  python3 scripts/expand_corpus_llm.py --provider openai --model gpt-4.1-mini --target 1000 --per-call 100

Notes:
  - Reads and preserves existing items; pads each level (easy/medium/hard) up to target.
  - Enforces style:
      zh: easy 日常词语; medium 简单句子; hard 优美华丽的句子
      en: easy daily words/phrases; medium simple daily sentences; hard ornate yet grammatical sentences
  - Requests strict JSON; validates and de-duplicates locally.
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Dict, List, Tuple

ROOT = Path(__file__).resolve().parents[1]
ZH_PATH = ROOT / 'HearCoachPlus' / 'Corpus' / 'chinese_corpus.json'
EN_PATH = ROOT / 'HearCoachPlus' / 'Corpus' / 'english_corpus.json'


def load_json(path: Path) -> Dict[str, List[str]]:
    with path.open('r', encoding='utf-8') as f:
        return json.load(f)


def save_json(path: Path, data: Dict[str, List[str]]):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def need(items: List[str], target: int) -> int:
    return max(0, target - len(items))


SYSTEM_PROMPT_ZH = (
    "你是一个数据整理助手。请根据要求返回 JSON。\n"
    "要求：\n"
    "- 严格输出 JSON，键名固定：easy, medium, hard。\n"
    "- 不要输出任何解释或额外文本。\n"
    "- 语言：中文（简体）。\n"
    "- easy: 日常词语（单词或极短词组），不含标点。\n"
    "- medium: 简单日常句子，口语自然，使用中文标点（句末'。'），每句 8-18 字为宜。\n"
    "- hard: 优美华丽的句子，意象自然流畅，句末'。'，避免生僻夸张。每句 15-30 字为宜。\n"
)

SYSTEM_PROMPT_EN = (
    "You are a data curation assistant. Return JSON only.\n"
    "Requirements:\n"
    "- Strict JSON object with keys: easy, medium, hard.\n"
    "- No explanations or extra text.\n"
    "- easy: daily words/short phrases (no punctuation).\n"
    "- medium: simple daily sentences (end with '.'), 5-12 words.\n"
    "- hard: elegant, lyrical but grammatical sentences (end with '.'), 10-22 words.\n"
)


def make_user_prompt(lang: str, level: str, count: int, forbidden: List[str]) -> str:
    forbid_blob = json.dumps(forbidden, ensure_ascii=False)
    if lang == 'zh':
        guidance = {
            'easy': '日常词语；主题不限但需生活常见；不要包含标点；避免专有名词。',
            'medium': '简单日常句子；情境真实；使用中文标点；句末用“。”；不要成段文字。',
            'hard': '优美华丽的句子；自然意象；避免堆砌辞藻与生僻；句末用“。”。',
        }[level]
    else:
        guidance = {
            'easy': 'Daily words/short phrases; no punctuation; avoid proper nouns.',
            'medium': 'Simple daily sentences; natural tone; end with a period.',
            'hard': 'Elegant/lyrical sentences; natural imagery; not purple prose; end with a period.',
        }[level]
    return (
        f"Language: {'Chinese (Simplified)' if lang=='zh' else 'English'}\n"
        f"Level: {level}\n"
        f"Count: {count}\n"
        f"Style guidance: {guidance}\n"
        f"Forbidden items (no overlap): {forbid_blob}\n"
        "Return STRICT JSON with exactly one array at the requested level, other levels empty arrays."
    )


def chat_openai(model: str, system_prompt: str, user_prompt: str, api_key: str) -> Dict:
    import requests
    url = "https://api.openai.com/v1/chat/completions"
    headers = {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json',
    }
    payload = {
        'model': model,
        'temperature': 0.7,
        'response_format': {'type': 'json_object'},
        'messages': [
            {'role': 'system', 'content': system_prompt},
            {'role': 'user', 'content': user_prompt},
        ],
    }
    r = requests.post(url, headers=headers, json=payload, timeout=120)
    r.raise_for_status()
    data = r.json()
    content = data['choices'][0]['message']['content']
    return json.loads(content)


def expand_level(provider: str, model: str, lang: str, level: str, existing: List[str], target: int, per_call: int, api_key: str) -> List[str]:
    items = list(existing)
    seen = set(items)
    sys_prompt = SYSTEM_PROMPT_ZH if lang == 'zh' else SYSTEM_PROMPT_EN

    while len(items) < target:
        batch = min(per_call, target - len(items))
        prompt = make_user_prompt(lang, level, batch, list(seen)[:500])  # send a capped forbid list
        if provider == 'openai':
            out = chat_openai(model, sys_prompt, prompt, api_key)
        else:
            raise ValueError(f'Unsupported provider: {provider}')

        new_list = out.get(level, []) or []
        # Basic sanitization per level
        for s in new_list:
            s = (s or '').strip()
            if not s:
                continue
            if level == 'easy':
                # strip terminal punctuation
                s = s.rstrip('.。!！?？')
            if s not in seen:
                seen.add(s)
                items.append(s)

        # backoff to avoid rate limits
        time.sleep(0.6)

        # Guard against bad outputs
        if batch > 1 and len(new_list) == 0:
            # reduce per_call on repeated empty outputs
            per_call = max(1, per_call // 2)
        if per_call == 1 and len(new_list) == 0:
            # give up to avoid infinite loop
            break

    return items[:target]


def run(provider: str, model: str, target: int, per_call: int, langs: List[str]):
    if provider == 'openai':
        api_key = os.environ.get('OPENAI_API_KEY')
        if not api_key:
            print('ERROR: OPENAI_API_KEY not set', file=sys.stderr)
            sys.exit(2)
    else:
        print(f'ERROR: unsupported provider {provider}', file=sys.stderr)
        sys.exit(2)

    if 'zh' in langs:
        zh = load_json(ZH_PATH)
        for level in ('easy','medium','hard'):
            need_count = need(zh.get(level, []), target)
            if need_count:
                zh[level] = expand_level(provider, model, 'zh', level, zh.get(level, []), target, per_call, api_key)
                print(f'zh {level}: -> {len(zh[level])}')
        save_json(ZH_PATH, zh)

    if 'en' in langs:
        en = load_json(EN_PATH)
        for level in ('easy','medium','hard'):
            need_count = need(en.get(level, []), target)
            if need_count:
                en[level] = expand_level(provider, model, 'en', level, en.get(level, []), target, per_call, api_key)
                print(f'en {level}: -> {len(en[level])}')
        save_json(EN_PATH, en)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--provider', default='openai', help='openai')
    ap.add_argument('--model', default='gpt-4.1-mini')
    ap.add_argument('--target', type=int, default=1000)
    ap.add_argument('--per-call', type=int, default=100)
    ap.add_argument('--langs', nargs='*', default=['zh','en'], help='subset: zh en')
    args = ap.parse_args()

    run(args.provider, args.model, args.target, args.per_call, args.langs)


if __name__ == '__main__':
    main()

