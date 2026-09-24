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

enter_menu_tty() {
  [[ -n "${menu_stty:-}" ]] || menu_stty="$(stty -g </dev/tty)"
  stty -echo -icanon min 1 time 0 </dev/tty
  printf '\033[?25l' >/dev/tty
}

leave_menu_tty() {
  if [[ -n "${menu_stty:-}" ]]; then
    stty "$menu_stty" </dev/tty 2>/dev/null || true
    menu_stty=""
  fi
  printf '\033[?25h' >/dev/tty 2>/dev/null || true
}

read_menu_key() {
  local key rest
  IFS= read -rsn1 key </dev/tty || return 1
  if [[ "$key" == $'\033' ]]; then
    stty -echo -icanon min 0 time 1 </dev/tty
    rest=""
    IFS= read -rsn2 rest </dev/tty || true
    stty -echo -icanon min 1 time 0 </dev/tty
    key="${key}${rest}"
  fi
  menu_key="$key"
}

draw_timezone_menu() {
  local i text
  {
    printf '选择节点所在时区。上下键移动，回车确认。\033[K\n'
    printf '只影响通过本工具启动的 Codex，不修改 macOS 系统时区。\033[K\n'
    if [[ -n "${menu_error:-}" ]]; then
      printf '%s\033[K\n' "$menu_error"
    else
      printf '\033[K\n'
    fi
    for i in "${!menu_labels[@]}"; do
      if [[ -n "${menu_zones[$i]}" ]]; then
        text="${menu_labels[$i]} — ${menu_zones[$i]}"
      else
        text="${menu_labels[$i]}"
      fi
      if [[ "$i" -eq "$menu_index" ]]; then
        printf '\033[7m> %s\033[0m\033[K\n' "$text"
      else
        printf '  %s\033[K\n' "$text"
      fi
    done
  } >/dev/tty
  menu_lines=$((3 + ${#menu_labels[@]}))
}

read_custom_timezone() {
  local input
  leave_menu_tty
  printf '输入城市代码或 IANA 时区名: ' >/dev/tty
  if ! IFS= read -r input </dev/tty; then
    echo "无法读取时区选择。" >&2
    exit 1
  fi
  menu_custom="$(normalize_timezone "$input")"
  if timezone_valid "$menu_custom"; then
    return 0
  fi
  menu_error="无法识别或不存在: ${input}"
  enter_menu_tty
  menu_jump=$((menu_lines + 1))
  return 1
}

choose_timezone() {
  local current="" default="" i tz
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

  menu_labels=(
    "洛杉矶 LAX"
    "纽约 NYC"
    "芝加哥 ORD"
    "丹佛 DEN"
    "凤凰城 PHX"
    "檀香山 HNL"
    "东京 TYO"
    "新加坡 SIN"
    "香港 HKG"
    "台北 TPE"
    "首尔 ICN"
    "伦敦 LHR"
    "法兰克福 FRA"
    "UTC"
    "手动输入"
  )
  menu_zones=(
    "America/Los_Angeles"
    "America/New_York"
    "America/Chicago"
    "America/Denver"
    "America/Phoenix"
    "Pacific/Honolulu"
    "Asia/Tokyo"
    "Asia/Singapore"
    "Asia/Hong_Kong"
    "Asia/Taipei"
    "Asia/Seoul"
    "Europe/London"
    "Europe/Berlin"
    "Etc/UTC"
    ""
  )
  menu_index=0
  menu_error=""
  menu_drawn=0
  menu_jump=0
  menu_custom=""
  if [[ -n "$default" ]]; then
    for i in "${!menu_zones[@]}"; do
      if [[ "${menu_zones[$i]}" == "$default" ]]; then
        menu_index="$i"
        break
      fi
    done
    if [[ "${menu_zones[$menu_index]}" != "$default" ]]; then
      menu_labels=("保持当前" "${menu_labels[@]}")
      menu_zones=("$default" "${menu_zones[@]}")
      menu_index=0
    fi
  fi

  enter_menu_tty
  trap 'leave_menu_tty; exit 130' INT
  while true; do
    if [[ "$menu_drawn" -eq 1 ]]; then
      if [[ "$menu_jump" -gt 0 ]]; then
        printf '\033[%dA' "$menu_jump" >/dev/tty
        menu_jump=0
      else
        printf '\033[%dA' "$menu_lines" >/dev/tty
      fi
    fi
    draw_timezone_menu
    menu_drawn=1
    if ! read_menu_key; then
      leave_menu_tty
      trap - INT
      echo "无法读取时区选择。" >&2
      exit 1
    fi
    case "$menu_key" in
      $'\033[A'|$'\033OA')
        menu_index=$((menu_index - 1))
        if [[ "$menu_index" -lt 0 ]]; then
          menu_index=$((${#menu_labels[@]} - 1))
        fi
        ;;
      $'\033[B'|$'\033OB')
        menu_index=$((menu_index + 1))
        if [[ "$menu_index" -ge ${#menu_labels[@]} ]]; then
          menu_index=0
        fi
        ;;
      ""|$'\r'|$'\n')
        if [[ -z "${menu_zones[$menu_index]}" ]]; then
          if read_custom_timezone; then
            leave_menu_tty
            trap - INT
            write_timezone_conf "$menu_custom"
            echo "已设置时区 ${menu_custom}"
            return
          fi
          continue
        fi
        tz="${menu_zones[$menu_index]}"
        leave_menu_tty
        trap - INT
        write_timezone_conf "$tz"
        echo "已设置时区 ${tz}"
        return
        ;;
    esac
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
