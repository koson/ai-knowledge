#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
knowledge_root="$script_dir"
system_file="$knowledge_root/system.txt"
model="${OLLAMA_MODEL:-gemma3:4b}"
auto_select=true
max_auto_files="${OLLAMA_MAX_KNOWLEDGE_FILES:-3}"
declare -a knowledge_files=()

usage() {
  cat <<'EOF'
Usage:
  ask-knowledge.sh [-m model] [-k file-or-dir]... [prompt]
  ask-knowledge.sh [-m model] [-k file-or-dir]... < prompt.txt

Options:
  -m MODEL         Ollama model to run. Default: gemma3:4b
  -k PATH          Knowledge file or directory under ai-knowledge/.
                   Repeat -k to add multiple files or folders.
  -K NUM           Maximum number of auto-selected knowledge files. Default: 3
  -n               Disable automatic knowledge selection when -k is omitted.
  -h               Show this help.

Examples:
  ask-knowledge.sh -k power-electronics/synchronous-buck.md "สรุปหลักการทำงานแบบสั้น"
  ask-knowledge.sh -m llama3.1 -k power-electronics "อธิบายหลักการ"
EOF
}

add_path() {
  local input_path="$1"
  local resolved_path

  if [[ "$input_path" = /* ]]; then
    resolved_path="$input_path"
  else
    resolved_path="$knowledge_root/$input_path"
  fi

  if [[ -d "$resolved_path" ]]; then
    while IFS= read -r file_path; do
      knowledge_files+=("$file_path")
    done < <(find "$resolved_path" -type f \( -name '*.md' -o -name '*.txt' \) | sort)
    return
  fi

  if [[ -f "$resolved_path" ]]; then
    knowledge_files+=("$resolved_path")
    return
  fi

  echo "Missing knowledge path: $input_path" >&2
  exit 1
}

collect_all_knowledge_files() {
  find "$knowledge_root" \
    -type f \
    \( -name '*.md' -o -name '*.txt' \) \
    ! -path "$system_file" \
    | sort
}

auto_select_paths() {
  local prompt_text="$1"
  local ranked_paths

  ranked_paths="$({
    printf '%s\n' "$prompt_text" | tr '[:upper:]' '[:lower:]' | sed 's/[^[:alnum:][:space:]-]/ /g' | awk '
      BEGIN {
        split("a an and are as at be by for from how in is of on or that the this to what when where which with", stop)
        for (i in stop) stopwords[stop[i]] = 1
      }
      {
        for (i = 1; i <= NF; i++) {
          token = $i
          if (length(token) >= 2 && !(token in stopwords)) query[token] = 1
        }
      }
      END {
        for (token in query) print token
      }
    '
  } | {
    while IFS= read -r file_path; do
      file_text="$(tr '[:upper:]' '[:lower:]' < "$file_path" | sed 's/[^[:alnum:][:space:]-]/ /g')"
      score=0
      while IFS= read -r token; do
        [[ -z "$token" ]] && continue
        path_text="${file_path#"$knowledge_root"/}"
        path_text="$(printf '%s' "$path_text" | tr '[:upper:]' '[:lower:]')"
        if grep -q -w -- "$token" <<< "$file_text"; then
          score=$((score + 3))
        fi
        if grep -q -- "$token" <<< "$path_text"; then
          score=$((score + 5))
        fi
      done < <(printf '%s\n' "$prompt_text" | tr '[:upper:]' '[:lower:]' | sed 's/[^[:alnum:][:space:]-]/ /g' | awk '
        BEGIN {
          split("a an and are as at be by for from how in is of on or that the this to what when where which with", stop)
          for (i in stop) stopwords[stop[i]] = 1
        }
        {
          for (i = 1; i <= NF; i++) {
            token = $i
            if (length(token) >= 2 && !(token in stopwords)) seen[token] = 1
          }
        }
        END {
          for (token in seen) print token
        }
      ')
      if (( score > 0 )); then
        printf '%s\t%s\n' "$score" "$file_path"
      fi
    done < <(collect_all_knowledge_files)
  } | sort -t $'\t' -k1,1nr -k2,2 | head -n "$max_auto_files" | cut -f2-)"

  if [[ -n "$ranked_paths" ]]; then
    while IFS= read -r file_path; do
      [[ -n "$file_path" ]] && knowledge_files+=("$file_path")
    done <<< "$ranked_paths"
  fi
}

dedupe_knowledge_files() {
  local deduped=()
  local seen=""

  for file_path in "${knowledge_files[@]}"; do
    if [[ ":$seen:" != *":$file_path:"* ]]; then
      deduped+=("$file_path")
      seen+="::$file_path"
    fi
  done

  knowledge_files=("${deduped[@]}")
}

while getopts ":m:k:K:nh" opt; do
  case "$opt" in
    m)
      model="$OPTARG"
      ;;
    k)
      auto_select=false
      add_path "$OPTARG"
      ;;
    K)
      max_auto_files="$OPTARG"
      ;;
    n)
      auto_select=false
      ;;
    h)
      usage
      exit 0
      ;;
    :) 
      echo "Option -$OPTARG requires a value." >&2
      usage >&2
      exit 1
      ;;
    \?)
      echo "Unknown option: -$OPTARG" >&2
      usage >&2
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1))

if [[ ! -f "$system_file" ]]; then
  echo "Missing system file: $system_file" >&2
  exit 1
fi

if [[ $# -gt 0 ]]; then
  prompt="$*"
else
  prompt="$(cat)"
fi

if [[ -z "${prompt//[$'\t\n\r ']/}" ]]; then
  echo "Prompt is empty." >&2
  usage >&2
  exit 1
fi

if [[ "$auto_select" = true ]]; then
  auto_select_paths "$prompt"
fi

dedupe_knowledge_files

tmp_prompt="$(mktemp)"
cleanup() {
  rm -f "$tmp_prompt"
}
trap cleanup EXIT

{
  cat "$system_file"
  if [[ ${#knowledge_files[@]} -gt 0 ]]; then
    printf '\n===== KNOWLEDGE BASE =====\n'
    for file_path in "${knowledge_files[@]}"; do
      relative_path="${file_path#"$knowledge_root"/}"
      printf '\n### %s\n' "$relative_path"
      cat "$file_path"
      printf '\n'
    done
  fi
  printf '\n===== USER REQUEST =====\n%s\n' "$prompt"
  printf '\n===== RESPONSE RULES =====\n'
  printf '%s\n' 'Use the knowledge base when it is relevant.'
  printf '%s\n' 'If the knowledge base is insufficient, say so briefly instead of inventing facts.'
} > "$tmp_prompt"

ollama run "$model" < "$tmp_prompt"