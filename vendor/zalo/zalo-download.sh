#!/usr/bin/env bash
# Helper sourced by install-zalo-linux.sh. No system configuration changes.

download_zalo_appimage() {
  local official_url="$1" target="$2" digest="$3"
  local candidate actual hash_expected=''
  local -a candidates=("$official_url")
  local -a curl_progress=(--silent --show-error)
  if [[ -t 2 && "${ZALO_DOWNLOAD_PROGRESS:-auto}" != off ]]; then
    # Real byte progress while downloading; keep CI pipes and logs compact.
    curl_progress=(--progress-bar)
  fi

  if [[ "$digest" =~ ^sha256:([[:xdigit:]]{64})$ ]]; then
    hash_expected="${BASH_REMATCH[1],,}"
    # The mirror is not trusted: it is only an alternate transport for the
    # exact official release asset. Every candidate must match the same digest.
    if [[ "${ZALO_DISABLE_PUBLIC_MIRRORS:-0}" != 1 ]]; then
      candidates+=("https://gh-proxy.com/$official_url" "https://ghproxy.net/$official_url")
    fi
    if [[ -n "${ZALO_MIRROR_URL:-}" ]]; then
      [[ "$ZALO_MIRROR_URL" == https://* ]] || { echo '[ZALO] ZALO_MIRROR_URL phải dùng HTTPS' >&2; return 2; }
      candidates+=("$ZALO_MIRROR_URL")
    fi
    if [[ -f "${ZALO_OFFLINE_APPIMAGE:-/dev/null}" ]]; then
      echo '[ZALO] Kiểm tra AppImage offline do người dùng cung cấp'
      cp -- "$ZALO_OFFLINE_APPIMAGE" "$target"
      actual="$(sha256sum "$target" | awk '{print $1}')"
      if [[ "$actual" == "$hash_expected" ]] && [[ "$(od -An -tx1 -N4 "$target" | tr -d '[:space:]')" == 7f454c46 ]]; then
        echo '[ZALO] Offline AppImage khớp SHA-256 upstream'
        return 0
      fi
      echo '[ZALO] Offline AppImage không khớp SHA-256/ELF; bỏ qua' >&2
      rm -f -- "$target"
    fi
  else
    echo '[ZALO] Upstream không có SHA-256 hợp lệ; không dùng nguồn mirror bên thứ ba' >&2
  fi

  for candidate in "${candidates[@]}"; do
    echo "[ZALO] Tải từ: ${candidate%%/https://*}"
    if ! curl --fail --location "${curl_progress[@]}" --retry 2 --connect-timeout 20 --max-time 900 "$candidate" -o "$target"; then
      rm -f -- "$target"
      continue
    fi
    if [[ -n "$hash_expected" ]]; then
      actual="$(sha256sum "$target" | awk '{print $1}')"
      if [[ "$actual" != "$hash_expected" ]]; then
        echo '[ZALO] SHA-256 sai; từ chối bản tải và thử nguồn tiếp theo' >&2
        rm -f -- "$target"
        continue
      fi
    fi
    if [[ "$(od -An -tx1 -N4 "$target" | tr -d '[:space:]')" != 7f454c46 ]]; then
      echo '[ZALO] Không phải ELF AppImage; từ chối bản tải' >&2
      rm -f -- "$target"
      continue
    fi
    if [[ -n "$hash_expected" ]]; then echo '[ZALO] Checksum SHA-256: OK'; fi
    return 0
  done
  return 1
}
