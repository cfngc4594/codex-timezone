#!/bin/bash
set -euo pipefail

REPO="cfngc4594/codex-timezone"
DEST="${HOME}/.codex-timezone"

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "$value"
}

read_conf_timezone() {
  local file="$1" line value
  [[ -f "$file" ]] || return 1
  line="$(grep -E '^[[:space:]]*TIMEZONE=' "$file" | tail -n 1 || true)"
  [[ -n "$line" ]] || return 1
  value="$(trim "${line#TIMEZONE=}")"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  [[ -n "$value" ]] || return 1
  printf '%s\n' "$value"
}

timezone_valid() {
  local tz="$1"
  [[ "$tz" =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ ]] || return 1
  [[ -e "/usr/share/zoneinfo/$tz" ]]
}

normalize_timezone() {
  local raw key
  raw="$(trim "$1")"
  key="$(printf '%s' "$raw" | tr '[:lower:]' '[:upper:]')"
  case "$key" in
    1|LAX|SFO|SJC|SEA|PDX|LA) printf '%s\n' "America/Los_Angeles" ;;
    2|NYC|JFK|EWR|IAD|WAS|MIA|ATL|BOS) printf '%s\n' "America/New_York" ;;
    3|ORD|CHI|DFW|DAL) printf '%s\n' "America/Chicago" ;;
    4|DEN) printf '%s\n' "America/Denver" ;;
    5|PHX) printf '%s\n' "America/Phoenix" ;;
    6|HNL) printf '%s\n' "Pacific/Honolulu" ;;
    7|TYO|NRT|HND|KIX|TOKYO) printf '%s\n' "Asia/Tokyo" ;;
    8|SIN|SGP|SG) printf '%s\n' "Asia/Singapore" ;;
    9|HKG|HK) printf '%s\n' "Asia/Hong_Kong" ;;
    10|TPE) printf '%s\n' "Asia/Taipei" ;;
    11|ICN|SEL) printf '%s\n' "Asia/Seoul" ;;
    12|LHR|LON|LONDON) printf '%s\n' "Europe/London" ;;
    13|FRA) printf '%s\n' "Europe/Berlin" ;;
    14|UTC|ETC/UTC) printf '%s\n' "Etc/UTC" ;;
    YVR) printf '%s\n' "America/Vancouver" ;;
    YYZ|YUL|TORONTO) printf '%s\n' "America/Toronto" ;;
    AMS) printf '%s\n' "Europe/Amsterdam" ;;
    CDG|PAR) printf '%s\n' "Europe/Paris" ;;
    SYD) printf '%s\n' "Australia/Sydney" ;;
    *) printf '%s\n' "$raw" ;;
  esac
}

write_timezone_conf() {
  local tz="$1"
  cat > "${DEST}/timezone.conf" <<EOF
# 只影响通过本工具启动的 Codex，不修改 macOS 系统时区。
# 需要 UTC 时写 Etc/UTC，不要写 UTC。
TIMEZONE=${tz}
EOF
}

tty_available() {
  ( : </dev/tty ) 2>/dev/null
}

choose_timezone() {
  local current="" default="" input tz
  if current="$(read_conf_timezone "${DEST}/timezone.conf")" && timezone_valid "$current"; then
    default="$current"
  elif [[ -n "${TIMEZONE:-}" ]] && timezone_valid "${TIMEZONE}"; then
    default="${TIMEZONE}"
  fi

  if ! tty_available; then
    if [[ -n "${TIMEZONE:-}" ]] && timezone_valid "${TIMEZONE}"; then
      write_timezone_conf "${TIMEZONE}"
      echo "已使用环境变量 TIMEZONE=${TIMEZONE}"
      return
    fi
    if [[ -n "$default" ]]; then
      echo "当前没有交互终端，保持已有时区 ${default}"
      return
    fi
    echo "请在终端里运行安装脚本以选择时区，或先设置 TIMEZONE=时区名。" >&2
    exit 1
  fi

  while true; do
    cat >/dev/tty <<'EOF'

选择节点所在时区。只影响通过本工具启动的 Codex，不修改 macOS 系统时区。
输入编号、城市代码（如 LAX、NRT）或 IANA 时区名。

  1) 洛杉矶 LAX — America/Los_Angeles
  2) 纽约 NYC — America/New_York
  3) 芝加哥 ORD — America/Chicago
  4) 丹佛 DEN — America/Denver
  5) 凤凰城 PHX — America/Phoenix
  6) 檀香山 HNL — Pacific/Honolulu
  7) 东京 TYO — Asia/Tokyo
  8) 新加坡 SIN — Asia/Singapore
  9) 香港 HKG — Asia/Hong_Kong
 10) 台北 TPE — Asia/Taipei
 11) 首尔 ICN — Asia/Seoul
 12) 伦敦 LHR — Europe/London
 13) 法兰克福 FRA — Europe/Berlin
 14) UTC — Etc/UTC

EOF
    if [[ -n "$default" ]]; then
      printf '直接回车保持 %s\n' "$default" >/dev/tty
    fi
    printf '请输入: ' >/dev/tty
    if ! IFS= read -r input </dev/tty; then
      echo "无法读取时区选择。" >&2
      exit 1
    fi
    if [[ -z "$(trim "$input")" ]]; then
      if [[ -n "$default" ]]; then
        input="$default"
      else
        echo "请选择一个时区。" >/dev/tty
        continue
      fi
    fi
    tz="$(normalize_timezone "$input")"
    if timezone_valid "$tz"; then
      write_timezone_conf "$tz"
      echo "已设置时区 ${tz}"
      return
    fi
    printf '无法识别或不存在: %s\n' "$input" >/dev/tty
  done
}

copy_tree() {
  local src="$1"
  mkdir -p "${DEST}/bin"
  cp "${src}/bin/codex-tz" "${DEST}/bin/codex-tz"
  chmod +x "${DEST}/bin/codex-tz"
  rm -rf "${DEST}/Codex.app"
  ditto "${src}/Codex.app" "${DEST}/Codex.app"
  rm -rf "${DEST}/Codex.app/Contents/_CodeSignature"
  chmod +x "${DEST}/Codex.app/Contents/MacOS/Codex"
  cp "${src}/timezone.conf.example" "${DEST}/timezone.conf.example"
}

if [[ -n "${BASH_SOURCE[0]-}" && -f "${BASH_SOURCE[0]}" ]]; then
  copy_tree "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' EXIT
  curl -fsSL "https://github.com/${REPO}/archive/refs/heads/main.tar.gz" | tar -xz -C "${tmp}" --strip-components 1
  copy_tree "${tmp}"
fi

choose_timezone
"${DEST}/bin/codex-tz" install
