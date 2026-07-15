#!/usr/bin/env bash

# CRYPTO_HASH PUZZLE BOT v2.0

set -o errexit
set -o pipefail
set -o nounset

# Garante que o Go esteja no PATH mesmo se o script rodar fora de um shell interativo
#export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"

# -------------------- CONFIGURAÇÃO --------------------
crypto_hash_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
PROGRESS_FILE="$crypto_hash_DIR/progresso_71.json"
RUNTIME_LOG="$crypto_hash_DIR/crypto_hash_runtime_71.log"  # ESSENCIAL - mantém
KEY_FOUND_FILE="$crypto_hash_DIR/KEYFOUNDKEYFOUND.txt"
RESULT_FILE="$crypto_hash_DIR/result_71.txt"
crypto_hash_BIN="$crypto_hash_DIR/crypto_hash"
GO_MAIN="$crypto_hash_DIR/main.go"

DEFAULT_KEYS_PER_SEC=43000000
REDUCED_LOGS=${REDUCED_LOGS:-0}
GO_RETRY_MAX=6
MIN_LOOP_SLEEP=0.5
GO_RETRY_BASE_SLEEP=0.5
KEY_CAPTURE_INTERVAL=300

#LOG_MAX_BYTES=104857600  # 100MB
#LOG_KEEP_BYTES=10485760  # 10MB
LOG_MAX_BYTES=10485760000  #10000MB
LOG_MAX_BYTES=10485760000  #10000MB

# -------------------- CORES (ANSI) --------------------
CSI="\u001b["
COLOR_RESET="${CSI}0m"
COLOR_GREEN="${CSI}32m"
COLOR_YELLOW="${CSI}33m"
COLOR_BLUE="${CSI}34m"
COLOR_MAGENTA="${CSI}35m"
COLOR_CYAN="${CSI}36m"
COLOR_BOLD="${CSI}1m"

# -------------------- FLAGS INTERNAS --------------------
crypto_hash_PID=""
STOP_REQUESTED=0
LAST_KEY=""
CURRENT_RANGE=""

# -------------------- UTILITÁRIOS --------------------
log() {
    if [ "$REDUCED_LOGS" -eq 1 ]; then
        case "$1" in
            ERROR|WARN) echo -e "$2" 1>&2 ;;
            *) : ;;
        esac
    else
        echo -e "$2"
    fi
}

color_echo() { echo -e "$1$2$COLOR_RESET"; }
exists()     { [ -e "$1" ]; }
kill_safe()  { if [ -n "${1:-}" ]; then kill "$1" 2>/dev/null || true; fi }

# -------------------- LEITURA DE PROGRESSO --------------------
read_progress_last_range() {
    if [ -f "$PROGRESS_FILE" ] && [ -s "$PROGRESS_FILE" ]; then
        if command -v jq >/dev/null 2>&1; then
            jq -r '.last_range // empty' "$PROGRESS_FILE" 2>/dev/null || true
        else
            grep -o '"last_range"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROGRESS_FILE" 2>/dev/null \
                | head -1 | sed 's/.*:\s*"\(.*\)"/\1/' || true
        fi
    fi
}

read_progress_last_key() {
    if [ -f "$PROGRESS_FILE" ] && [ -s "$PROGRESS_FILE" ]; then
        if command -v jq >/dev/null 2>&1; then
            jq -r '.last_key_seen // empty' "$PROGRESS_FILE" 2>/dev/null || true
        else
            grep -o '"last_key_seen"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROGRESS_FILE" 2>/dev/null \
                | head -1 | sed 's/.*:\s*"\(.*\)"/\1/' || true
        fi
    fi
}

save_progress() {
    local save_range="${CURRENT_RANGE:-}"
    if [ -n "${LAST_KEY:-}" ] && [ -n "${CURRENT_RANGE:-}" ]; then
        local range_to="${CURRENT_RANGE##*:}"
        save_range="${LAST_KEY}:${range_to}"
    fi

    cat <<EOF > "$PROGRESS_FILE"
{
  "last_range": "${save_range}",
  "last_key_seen": "${LAST_KEY:-}",
  "timestamp": "$(date +%s)",
  "timestamp_human": "$(date --iso-8601=seconds)"
}
EOF
    log INFO "💾 progresso_71.json atualizado (range: ${save_range} | chave: ${LAST_KEY:-desconhecida})"
}

# -------------------- CAPTURA DE CHAVE (CORRIGIDA) --------------------
capture_current_key() {
    local key=""

    if [ -f "$RUNTIME_LOG" ] && [ -s "$RUNTIME_LOG" ]; then
        key=$(tail -c 10485760 "$RUNTIME_LOG" 2>/dev/null \
              | tr '\r' '\n' \
              | grep -oE "Base key: [0-9a-fA-F]{16,}" \
              | tail -1 \
              | grep -oE "[0-9a-fA-F]{16,}" || true)
    fi

    if [ -n "$key" ]; then
        if [ -n "$LAST_KEY" ]; then
            if [[ "${key,,}" > "${LAST_KEY,,}" ]]; then
                LAST_KEY="$key"
                color_echo "$COLOR_GREEN" "🔍 Chave atualizada: $LAST_KEY"
            fi
        else
            LAST_KEY="$key"
            color_echo "$COLOR_GREEN" "🔍 Chave inicial capturada: $LAST_KEY"
        fi
        return 0
    fi

    color_echo "$COLOR_GREEN" "⚠️  Nenhuma chave detectada ainda"
    return 1
}

# -------------------- ROTAÇÃO DO LOG --------------------
rotate_log_if_needed() {
    [ -f "$RUNTIME_LOG" ] || return 0
    [ -s "$RUNTIME_LOG" ] || return 0

    local size
    size=$(stat -c%s "$RUNTIME_LOG" 2>/dev/null || echo 0)

    if [ "$size" -ge "$LOG_MAX_BYTES" ]; then
        local tmp_log="${RUNTIME_LOG}.tmp"
        tail -c "$LOG_KEEP_BYTES" "$RUNTIME_LOG" > "$tmp_log" 2>/dev/null || true
        mv -f "$tmp_log" "$RUNTIME_LOG" 2>/dev/null || true
    fi
}

# -------------------- RANGE E ETA --------------------
extract_range() {
    local hex_key=""
    if [ -f "$RESULT_FILE" ]; then
        hex_key=$(grep -oE "0x[0-9a-fA-F]{6,}\b" "$RESULT_FILE" | tail -1 | sed 's/^0x//' || true)
        [ -z "$hex_key" ] && hex_key=$(grep -oE "[0-9a-fA-F]{8,}" "$RESULT_FILE" | tail -1 || true)
    fi

    [ -z "$hex_key" ] && hex_key="4ec5d37314c2000000"
    echo "${hex_key%??????}000000:7fffffffffffffffff"
}

hex_to_dec() {
    if [ -z "$1" ]; then echo 0; return; fi
    echo "ibase=16; ${1^^}" | bc
}

compute_eta_hours() {
    local from_hex=${CURRENT_RANGE%%:*}
    local to_hex=${CURRENT_RANGE##*:}
    from_hex=${from_hex#0x}
    to_hex=${to_hex#0x}

    local from_dec
    from_dec=$(hex_to_dec "$from_hex")
    local to_dec=0

    if [[ ${#to_hex} -le 16 ]]; then
        to_dec=$(hex_to_dec "$to_hex")
    else
        to_dec=$(hex_to_dec "${to_hex:0:16}")
        to_dec=$((to_dec * 16 ** (${#to_hex}-16)))
    fi

    local total_keys
    total_keys=$(echo "$to_dec - $from_dec + 1" | bc)

    local kps=$DEFAULT_KEYS_PER_SEC
    if [ -f "$RUNTIME_LOG" ] && [ -s "$RUNTIME_LOG" ]; then
        local mdet
        mdet=$(tail -c 131072 "$RUNTIME_LOG" 2>/dev/null | tr '\r' '\n' \
               | grep -oE "~?[0-9]+ Mkeys/s" | tail -1 | tr -d '~ Mkeys/s' || true)
        if [ -n "$mdet" ]; then
            kps=$((mdet * 1000000))
        fi
    fi

    [ -z "$kps" ] || [ "$kps" -le 0 ] && kps=$DEFAULT_KEYS_PER_SEC

    local hours
    hours=$(echo "scale=6; $total_keys / $kps / 3600" | bc -l)
    echo "$hours"
}

show_eta() {
    local hours h_int mins
    hours=$(compute_eta_hours)
    h_int=$(echo "$hours/1" | bc)
    mins=$(echo "scale=0; ($hours - $h_int) * 60" | bc)
    color_echo "$COLOR_GREEN" "⏱ ETA aproximado para o range atual: ${h_int}h (~${mins}min)"
}

# -------------------- GO RUN COM RETRY --------------------
run_go_with_retry() {
    local attempt=0
    while [ $attempt -lt $GO_RETRY_MAX ]; do
        if [ -f "$GO_MAIN" ]; then
            if [ "$REDUCED_LOGS" -eq 1 ]; then
                (cd "$crypto_hash_DIR" && go run "$GO_MAIN" >/dev/null 2>&1) && return 0 || true
            else
                (cd "$crypto_hash_DIR" && go run "$GO_MAIN") && return 0 || true
            fi
        else
            log ERROR "Arquivo main_71.go não encontrado em $crypto_hash_DIR"
            return 1
        fi
        attempt=$((attempt + 1))
        local sleep_time
        sleep_time=$(LC_NUMERIC=C printf "%.0f" "$(echo "scale=2; x=$GO_RETRY_BASE_SLEEP * (2 ^ $attempt); if(x>8) 8 else x" | bc -l)")
        log WARN "go run falhou — tentativa $attempt/$GO_RETRY_MAX — aguardando ${sleep_time}s"
        sleep "$sleep_time"
    done
    log ERROR "go run falhou após $GO_RETRY_MAX tentativas"
    return 1
}

# -------------------- SINAIS --------------------
_on_signal() {
    STOP_REQUESTED=1
    color_echo "$COLOR_GREEN" "\n⚠️  Sinal recebido — solicitando parada..."

    # Captura antes de matar (log pode ainda estar sendo escrito)
    capture_current_key || true

    kill_safe "$crypto_hash_PID"

    # Aguarda o processo terminar e o tee fazer flush
    wait "$crypto_hash_PID" 2>/dev/null || true
    sleep 1

    # Captura novamente após flush completo do log
    capture_current_key || true
    save_progress || true
    color_echo "$COLOR_GREEN" "✔ Progresso salvo (chave: ${LAST_KEY:-desconhecida}). Saindo."
    exit 0
}
trap _on_signal INT TERM

# -------------------- MENU --------------------
color_echo "$COLOR_GREEN" "╔═══════════════════════════════════╗"
color_echo "$COLOR_GREEN" "║=== CRYPTO_HASH PUZZLE BOT v2.0 ===║"
color_echo "$COLOR_GREEN" "╚═══════════════════════════════════╝"
color_echo "$COLOR_GREEN" "╔═══════════╗"
color_echo "$COLOR_GREEN" "║1- Iniciar ║" 
color_echo "$COLOR_GREEN" "╚═══════════╝"

read -rp " Opção:" _choice || true

color_echo "$COLOR_GREEN" "╔═════════════════════════════════════════╗"
color_echo "$COLOR_GREEN" "║Selecione o tempo de execução por range: ║"
color_echo "$COLOR_GREEN" "╚═════════════════════════════════════════╝"
color_echo "$COLOR_GREEN" "╔═════╗╔═════╗╔═════╗╔═════╗╔═════╗╔═════╗╔═════╗╔═════╗╔═════╗╔═════╗╔═════╗"                                                                      
color_echo "$COLOR_GREEN" "║0- 2m║║1- 1h║║2- 2h║║3- 3h║║4- 4h║║5- 5h║║6- 6h║║7-12h║║8-24h║║9-72h║║10-7d║"
color_echo "$COLOR_GREEN" "╚═════╝╚═════╝╚═════╝╚═════╝╚═════╝╚═════╝╚═════╝╚═════╝╚═════╝╚═════╝╚═════╝"                                                                           
read -rp "Opção: " time_opt || true

case $time_opt in
    0) DURATION=120 ;;
    1) DURATION=3600 ;;
    2) DURATION=7200 ;;
    3) DURATION=10800 ;;
    4) DURATION=14400 ;;
    5) DURATION=18000 ;;
    6) DURATION=21600 ;;
    7) DURATION=43200 ;;
    8) DURATION=86400 ;;
    9) DURATION=259200 ;;
   10) DURATION=604800 ;;
    *) DURATION=3600 ;;
esac

color_echo "$COLOR_GREEN" "⏱ Duração por range: $((DURATION/3600))h $((DURATION%3600/60))m"

# Verificar progresso salvo
LAST_RANGE_ON_DISK=$(read_progress_last_range || true)
LAST_KEY_ON_DISK=$(read_progress_last_key || true)
START_FROM_LAST=0

if [ -n "$LAST_RANGE_ON_DISK" ]; then
    color_echo "$COLOR_GREEN" "╔═══════════════════════════╗"
    color_echo "$COLOR_GREEN" "║ ♻️ Progresso encontrado:   ║"
    color_echo "$COLOR_GREEN" "╚═══════════════════════════╝"
    color_echo "$COLOR_GREEN" "╔════════════════════════════════════════════════════════╗"
    color_echo "$COLOR_GREEN" "║ Range original:$LAST_RANGE_ON_DISK   ║"                    
    color_echo "$COLOR_GREEN" "║ Última chave:${LAST_KEY_ON_DISK:-desconhecida}                              ║"
    color_echo "$COLOR_GREEN" "╚════════════════════════════════════════════════════════╝"

    read -rp "Deseja retomar desse ponto? (s/N): " yn || true
    if [[ "$yn" =~ ^[sS] ]]; then
        START_FROM_LAST=1
        CURRENT_RANGE="$LAST_RANGE_ON_DISK"
        LAST_KEY="${LAST_KEY_ON_DISK:-}"
        color_echo "$COLOR_GREEN" "✔ Retomando — chave de referência: ${LAST_KEY:-início do range}"
    fi
fi

iteration=1

# -------------------- LOOP PRINCIPAL --------------------
while true; do
    [ "$STOP_REQUESTED" -eq 1 ] && break

    color_echo "$COLOR_GREEN" "\n🔁 === ITERAÇÃO $iteration ==="

    if exists "$KEY_FOUND_FILE"; then
        color_echo "$COLOR_GREEN" "🎉 CHAVE encontrada ($KEY_FOUND_FILE) — encerrando."
        capture_current_key || true
        save_progress || true
        break
    fi

    cd "$crypto_hash_DIR"

    if [ "$iteration" -eq 1 ] && [ "$START_FROM_LAST" -eq 1 ] && [ -n "$CURRENT_RANGE" ]; then
        if [ -n "$LAST_KEY" ]; then
            range_to="${CURRENT_RANGE##*:}"
            CURRENT_RANGE="${LAST_KEY}:${range_to}"
            color_echo "$COLOR_GREEN" "🎯 Retomando da última chave: $CURRENT_RANGE"
        else
            color_echo "$COLOR_GREEN" "🎯 Retomando do range salvo: $CURRENT_RANGE"
        fi
    else
        log INFO "🎲 Gerando novo range..."
        run_go_with_retry || true
        CURRENT_RANGE=$(extract_range)
        LAST_KEY=""
        color_echo "$COLOR_GREEN" "🎯 RANGE GERADO: $CURRENT_RANGE"
    fi

    # Limpa apenas o log principal
    : > "$RUNTIME_LOG"

    show_eta || true

    if [ -x "$crypto_hash_BIN" ]; then
        if [ "$REDUCED_LOGS" -eq 1 ]; then
            "$crypto_hash_BIN" -m rmd160 -f tests/71.rmd -t 24 -l compress -6 -S -e -r "$CURRENT_RANGE" -n 4096 \
                > "$RUNTIME_LOG" 2>&1 &
        else
            "$crypto_hash_BIN" -m rmd160 -f tests/71.rmd -t 24 -l compress -6 -S -e -r "$CURRENT_RANGE" -n 4096 \
                2>&1 | tee "$RUNTIME_LOG" &
        fi
        crypto_hash_PID=$!
        color_echo "$COLOR_GREEN" "📌 crypto_hash PID: $crypto_hash_PID"
    else
        log ERROR "$crypto_hash_BIN não encontrado ou não executável"
        exit 1
    fi

    sleep 3
    capture_current_key || true
    save_progress || true

    SECONDS_RUN=0
    LAST_CAPTURE_AT=0

    # -------------------- LOOP DE MONITORAMENTO --------------------
    while true; do
        if [ "$STOP_REQUESTED" -eq 1 ]; then
            color_echo "$COLOR_GREEN" "Parada solicitada — encerrando crypto_hash..."
            kill_safe "$crypto_hash_PID"
            wait "$crypto_hash_PID" 2>/dev/null || true
            capture_current_key || true
            save_progress || true
            exit 0
        fi

        if exists "$KEY_FOUND_FILE"; then
            color_echo "$COLOR_GREEN" "\n🎉🎉 CHAVE ENCONTRADA — PARADA GRACEFUL 🎉🎉"
            kill_safe "$crypto_hash_PID"
            wait "$crypto_hash_PID" 2>/dev/null || true
            capture_current_key || true
            save_progress || true
            exit 0
        fi

        if ! kill -0 "$crypto_hash_PID" 2>/dev/null; then
            log WARN "⚠ crypto_hash finalizou antes do tempo (PID $crypto_hash_PID)."
            break
        fi

        sleep 1
        SECONDS_RUN=$((SECONDS_RUN + 1))

        SECS_SINCE_CAPTURE=$((SECONDS_RUN - LAST_CAPTURE_AT))
        if [ "$SECS_SINCE_CAPTURE" -ge "$KEY_CAPTURE_INTERVAL" ]; then
            rotate_log_if_needed || true
            capture_current_key || true
            save_progress || true
            LAST_CAPTURE_AT=$SECONDS_RUN
            ELAPSED_MIN=$((SECONDS_RUN / 60))
            REMAINING_MIN=$(((DURATION - SECONDS_RUN) / 60))
            color_echo "$COLOR_GREEN" "   ⏳ ${ELAPSED_MIN}min decorridos | ~${REMAINING_MIN}min restantes"
        fi

        if [ "$SECONDS_RUN" -ge "$DURATION" ]; then
            color_echo "$COLOR_GREEN" "⏹ Tempo de $((DURATION/3600))h concluído — finalizando PID $crypto_hash_PID..."
            kill_safe "$crypto_hash_PID"
            wait "$crypto_hash_PID" 2>/dev/null || true
            break
        fi
    done

    capture_current_key || true
    save_progress || true

    color_echo "$COLOR_GREEN" "🏁 Iteração $iteration completa. Chave final: ${LAST_KEY:-desconhecida}"
    iteration=$((iteration + 1))

    sleep "$MIN_LOOP_SLEEP"
    START_FROM_LAST=0
done

color_echo "$COLOR_GREEN" "\n✅ BOT finalizado."