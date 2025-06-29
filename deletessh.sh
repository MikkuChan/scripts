#!/bin/bash
# ==================================================
# System Request : Debian 9+/Ubuntu 18.04+/20+
# ==================================================

export PATH=$PATH:/usr/sbin:/sbin
valid_auth="${AUTHKEY:-default_fallback}"

# Fungsi untuk melisting user SSH (khusus response JSON)
list_users() {
    echo '{"status":"success","users":['
    first=1
    while read expired
    do
        AKUN="$(echo $expired | cut -d: -f1)"
        ID="$(echo $expired | grep -v nobody | cut -d: -f3)"
        exp="$(chage -l $AKUN | grep "Account expires" | awk -F": " '{print $2}')"
        status="$(passwd -S $AKUN | awk '{print $2}' )"
        if [[ $ID -ge 1000 ]]; then
            if [[ $first -eq 0 ]]; then echo -n ','; fi
            first=0
            echo -n "{\"user\":\"$AKUN\",\"exp\":\"$exp\",\"status\":\"$status\"}"
        fi
    done < /etc/passwd
    echo ']}'
}

if [ "$REQUEST_METHOD" = "GET" ]; then
    # --- Ambil parameter ---
    user=$(echo "$QUERY_STRING" | sed -n 's/^.*user=\([^&]*\).*$/\1/p')
    auth=$(echo "$QUERY_STRING" | sed -n 's/^.*auth=\([^&]*\).*$/\1/p')
    action=$(echo "$QUERY_STRING" | sed -n 's/^.*action=\([^&]*\).*$/\1/p')

    # Jika action=list, tampilkan list user (fitur tambahan)
    if [[ "$action" == "list" ]]; then
        list_users
        exit 0
    fi

    # --- Validasi param ---
    if [ -z "$user" ] || [ -z "$auth" ]; then
        echo '{"status":"error","message":"Parameter user dan auth diperlukan"}'
        exit 1
    fi
    if [ "$auth" != "$valid_auth" ]; then
        echo '{"status":"error","message":"Kunci autentikasi salah"}'
        exit 1
    fi

    # --- Cek user dan proses hapus ---
    if getent passwd "$user" > /dev/null 2>&1; then
        result=$(sudo userdel -r "$user" 2>&1)
        status=$?
        if [ $status -eq 0 ]; then
            echo '{"status":"success","message":"User '"$user"' berhasil dihapus"}'
        else
            echo '{"status":"error","message":"Gagal menghapus user!","details":"'"$result"'"}'
        fi
        exit $status
    else
        echo '{"status":"error","message":"User '"$user"' tidak ditemukan"}'
        exit 1
    fi
fi

echo '{"status":"error","message":"Script hanya mendukung mode API via HTTP GET"}'
exit 1
