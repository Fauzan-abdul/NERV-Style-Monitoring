#!/bin/bash
# ==========================================================
#  LINUX SYSTEM MONITOR  //  NERV TACTICAL DISPLAY
#  Proyek Sistem Operasi (TIK103) - Pertemuan 12
#
#  Penggunaan : ./monitor.sh [cpu|mem|disk|all|live|help]
#  Tanpa argumen akan membuka menu interaktif.
#  Log        : ~/project-monitoring/logs/monitor.log
# ==========================================================

LOG_DIR="${LOG_DIR:-$HOME/project-monitoring/logs}"
LOG_FILE="$LOG_DIR/monitor.log"
BAR_WIDTH=40
LINE_WIDTH=72

# Membuat direktori log jika belum tersedia
mkdir -p "$LOG_DIR"

# ---------- Warna (gaya HUD Evangelion) ----------
if [[ ( -t 1 || -n "${FORCE_COLOR:-}" ) && -z "${NO_COLOR:-}" ]]; then
  USE_COLOR=1
  RED=$'\e[1;38;5;196m'   # judul / garis
  ORG=$'\e[1;38;5;208m'   # label
  WHT=$'\e[38;5;252m'     # nilai
  DIM=$'\e[38;5;238m'     # segmen bar kosong
  RST=$'\e[0m'
else
  USE_COLOR=0; RED=""; ORG=""; WHT=""; DIM=""; RST=""
fi
# Gradasi teal -> biru untuk segmen bar
GRAD=(86 85 79 80 74 38 32 33 27 26 21)

# ---------- Helper tampilan ----------
hr() {
  local i
  printf '%s' "$RED"
  for ((i = 0; i < LINE_WIDTH; i++)); do printf '─'; done
  printf '%s\n' "$RST"
}

# Format angka persen per-sepuluh (mis. 343 -> 34.3)
fmt10() { printf '%d.%d' $(( $1 / 10 )) $(( $1 % 10 )); }

# Bar segmen: argumen = persen per-sepuluh (0..1000)
bar() {
  local p10=$1 filled i c out=""
  (( p10 > 1000 )) && p10=1000
  (( p10 < 0 )) && p10=0
  filled=$(( p10 * BAR_WIDTH / 1000 ))
  for ((i = 0; i < BAR_WIDTH; i++)); do
    if (( USE_COLOR )); then
      if (( i < filled )); then
        c=${GRAD[$(( i * ${#GRAD[@]} / BAR_WIDTH ))]}
        out+=$'\e[38;5;'"${c}"'m▮'
      else
        out+="${DIM}▮"
      fi
    else
      if (( i < filled )); then out+="#"; else out+="-"; fi
    fi
  done
  printf '%s%s' "$out" "$RST"
}

status_text() {
  local p=$(( $1 / 10 ))
  if   (( p >= 85 )); then echo "CRITICAL"
  elif (( p >= 60 )); then echo "CAUTION"
  else echo "NOMINAL"; fi
}

status_colored() {
  local t; t=$(status_text "$1")
  case $t in
    CRITICAL) printf '%s%s%s' "$RED" "$t" "$RST" ;;
    CAUTION)  printf '%s%s%s' "$ORG" "$t" "$RST" ;;
    *)        printf '%s%s%s' "$WHT" "$t" "$RST" ;;
  esac
}

kv() { printf '%s%s%s %s%s%s' "$ORG" "$1" "$RST" "$WHT" "$2" "$RST"; }

section() { printf ' %s▌%s %s%s%s\n' "$RED" "$RST" "$ORG" "$1" "$RST"; }

# Mewarnai tabel dari stdin: baris pertama = header
table() {
  local first=1 l
  while IFS= read -r l; do
    if (( first )); then
      printf ' %s%s%s\n' "$ORG" "$l" "$RST"; first=0
    else
      printf ' %s%s%s\n' "$WHT" "$l" "$RST"
    fi
  done
}

# Satu blok SUBJECT: nomor, kode, nama, persen per-sepuluh, detail
subject() {
  local no=$1 code=$2 name=$3 p10=$4 detail=$5
  printf ' %sSUBJECT %s%s  %s  %s%6s%%%s  ' "$RED" "$no" "$RST" "$(bar "$p10")" "$ORG" "$(fmt10 "$p10")" "$RST"
  status_colored "$p10"; printf '\n'
  printf ' %s%-10s%s  %s%-7s%s %s%s%s\n' "$ORG" "$code" "$RST" "$RED" "$name" "$RST" "$WHT" "$detail" "$RST"
}

# ---------- Pengumpulan data ----------
cpu_sample() {
  local u n s i io irq sirq st t1 t2 i1 i2 dt di
  read -r _ u n s i io irq sirq st _ < /proc/stat
  t1=$(( u + n + s + i + io + irq + sirq + st )); i1=$(( i + io ))
  sleep 0.5
  read -r _ u n s i io irq sirq st _ < /proc/stat
  t2=$(( u + n + s + i + io + irq + sirq + st )); i2=$(( i + io ))
  dt=$(( t2 - t1 )); di=$(( i2 - i1 ))
  if (( dt > 0 )); then CPU10=$(( 1000 * (dt - di) / dt )); else CPU10=0; fi
  CPU_CORES=$(nproc 2>/dev/null || echo 1)
}

mem_sample() {
  local total avail
  total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
  avail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
  MEM_TOTAL_MB=$(( total / 1024 ))
  MEM_USED_MB=$(( (total - avail) / 1024 ))
  MEM10=$(( 1000 * (total - avail) / total ))
}

disk_sample() {
  read -r DISK_SIZE DISK_USED DISK_AVAIL DISK_PCT < <(df -P -h / | awk 'NR==2{print $2, $3, $4, $5}')
  DISK10=$(( ${DISK_PCT%\%} * 10 ))
}

collect() {
  HOST=$(hostname)
  KERNEL=$(uname -srm)
  NOW=$(date '+%Y-%m-%d %H:%M:%S')
  UPTIME_P=$(uptime -p 2>/dev/null || uptime)
  LOAD=$(cut -d' ' -f1-3 /proc/loadavg)
  PROCS=$(ps -e --no-headers | wc -l)
  cpu_sample
  mem_sample
  disk_sample
}

# ---------- Tampilan ----------
show_header() {
  hr
  printf ' %sLINUX SYSTEM RESOURCE LEVEL%s\n' "$RED" "$RST"
  printf ' '; kv "HOSTNAME" "$HOST"; printf '    '; kv "TIME" "$NOW"; printf '\n'
  printf ' '; kv "KERNEL" "$KERNEL"; printf '\n'
  printf ' '; kv "ELAPSED" "$UPTIME_P"; printf '    '
  kv "PROCESSES" "$PROCS"; printf '    '; kv "LOAD" "$LOAD"; printf '\n'
  hr
  printf '%s%14s%-10s%-10s%-10s%-10s%s%s\n' "$DIM" "" 0 25 50 75 100 "$RST"
}

sub_cpu()  { subject 00 "FIRST .C"  "CPU"    "$CPU10"  "${CPU_CORES} core   load $LOAD"; }
sub_mem()  { subject 01 "THIRD .C"  "MEMORY" "$MEM10"  "${MEM_USED_MB} MB / ${MEM_TOTAL_MB} MB"; }
sub_disk() { subject 02 "SECOND .C" "DISK /" "$DISK10" "${DISK_USED} / ${DISK_SIZE}  (free ${DISK_AVAIL})"; }

det_cpu() {
  section "TOP 5 PROCESSES BY CPU"
  ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6 | table
}
det_mem() {
  section "MEMORY  (free -h)"
  free -h | table
}
det_disk() {
  section "ALL FILESYSTEMS  (df -h)"
  df -h | table
}

write_log() {
  local scope=$1 ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  {
    echo "===== MONITORING [$scope] ====="
    echo "HOSTNAME=$HOST KERNEL=\"$KERNEL\""
    echo "UPTIME=\"$UPTIME_P\" PROCESSES=$PROCS LOAD=\"$LOAD\""
    echo "CPU=$(fmt10 "$CPU10")% [$(status_text "$CPU10")] MEM=$(fmt10 "$MEM10")% [$(status_text "$MEM10")] (${MEM_USED_MB}MB/${MEM_TOTAL_MB}MB) DISK=${DISK_PCT} [$(status_text "$DISK10")] (${DISK_USED}/${DISK_SIZE})"
    if [[ $scope == cpu || $scope == all ]]; then
      echo "-- TOP 5 CPU --"
      ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6
    fi
    if [[ $scope == mem || $scope == all ]]; then
      echo "-- MEMORY --"
      free -h
    fi
    if [[ $scope == disk || $scope == all ]]; then
      echo "-- DISK (SEMUA FILESYSTEM) --"
      df -h
    fi
  } | sed "s/^/[$ts] /" >> "$LOG_FILE"
  echo >> "$LOG_FILE"
}

# run_scope <cpu|mem|disk|all> [simpan_log: 1|0]
run_scope() {
  local scope=$1 dolog=${2:-1}
  collect
  show_header
  case $scope in
    cpu)  sub_cpu;  echo; det_cpu ;;
    mem)  sub_mem;  echo; det_mem ;;
    disk) sub_disk; echo; det_disk ;;
    all)
      sub_cpu; echo; sub_mem; echo; sub_disk; echo
      det_cpu; echo; det_mem; echo; det_disk ;;
  esac
  hr
  if (( dolog )); then
    write_log "$scope"
    printf ' %sLOG SAVED%s %s%s%s\n' "$ORG" "$RST" "$WHT" "$LOG_FILE" "$RST"
  fi
}

live() {
  trap ':' INT
  (
    trap 'exit 0' INT
    while true; do
      clear 2>/dev/null
      run_scope all 0
      printf ' %sLIVE MODE - tekan Ctrl+C untuk berhenti%s\n' "$DIM" "$RST"
      sleep 1.5
    done
  )
  trap - INT
}

menu() {
  local pilih
  while true; do
    clear 2>/dev/null
    hr
    printf ' %sNERV // LINUX SYSTEM MONITOR%s\n' "$RED" "$RST"
    hr
    printf ' %s[1]%s SUBJECT 00 :: CPU & proses\n'   "$ORG" "$RST"
    printf ' %s[2]%s SUBJECT 01 :: Memori\n'          "$ORG" "$RST"
    printf ' %s[3]%s SUBJECT 02 :: Disk\n'            "$ORG" "$RST"
    printf ' %s[4]%s Semua subject\n'                 "$ORG" "$RST"
    printf ' %s[5]%s Live mode (refresh otomatis)\n' "$ORG" "$RST"
    printf ' %s[0]%s Keluar\n'                        "$ORG" "$RST"
    hr
    printf ' %sPILIH >%s ' "$RED" "$RST"
    read -r pilih || break
    case $pilih in
      1) clear 2>/dev/null; run_scope cpu ;;
      2) clear 2>/dev/null; run_scope mem ;;
      3) clear 2>/dev/null; run_scope disk ;;
      4) clear 2>/dev/null; run_scope all ;;
      5) live; continue ;;
      0|q|Q) echo " MAGI SYSTEM DISCONNECTED."; break ;;
      *) echo " Pilihan tidak valid."; sleep 1; continue ;;
    esac
    printf '\n %sTekan Enter untuk kembali ke menu...%s' "$DIM" "$RST"
    read -r _ || break
  done
}

usage() {
  cat <<'EOF'
Linux System Monitor - NERV edition

Penggunaan: ./monitor.sh [perintah]

  (kosong)   menu interaktif
  cpu        monitoring CPU + 5 proses teratas
  mem        monitoring memori
  disk       monitoring disk (semua filesystem)
  all        semua monitoring sekaligus
  live       tampilan live (Ctrl+C untuk berhenti)
  help       bantuan ini

Variabel opsional:
  NO_COLOR=1     matikan warna
  FORCE_COLOR=1  paksa warna (mis. saat output di-pipe)
  LOG_DIR=path   ganti direktori log
EOF
}

case "${1:-menu}" in
  cpu|mem|disk|all) run_scope "$1" ;;
  live)             live ;;
  menu)             menu ;;
  help|-h|--help)   usage ;;
  *)                usage; exit 1 ;;
esac
