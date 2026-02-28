#!/bin/bash
# oci-keepalive.sh

set -e

MAX_LOAD=0.7
MAX_CPU=15

apt update
apt install -y bc curl

cat > /usr/local/bin/keepalive-oci.sh << 'EOF'
#!/bin/bash

MAX_LOAD=0.7
MAX_CPU=15

# Obtener carga promedio
LOAD=$(awk '{print $1}' /proc/loadavg)

# Calcular uso de CPU
CPU_IDLE1=$(awk '/^cpu / {print $5}' /proc/stat)
CPU_TOTAL1=$(awk '/^cpu / {sum=0; for(i=2;i<=NF;i++) sum+=\$i; print sum}' /proc/stat)
sleep 1
CPU_IDLE2=$(awk '/^cpu / {print $5}' /proc/stat)
CPU_TOTAL2=$(awk '/^cpu / {sum=0; for(i=2;i<=NF;i++) sum+=\$i; print sum}' /proc/stat)
CPU_IDLE=$((CPU_IDLE2 - CPU_IDLE1))
CPU_TOTAL=$((CPU_TOTAL2 - CPU_TOTAL1))
CPU_USAGE=$((100 * (CPU_TOTAL - CPU_IDLE) / CPU_TOTAL))

# Contar usuarios conectados
USERS=$(who | wc -l)

# Ejecutar acciones solo si servidor está libre
if (( $(echo "$LOAD < $MAX_LOAD" | bc -l) )) && \
   [ "$CPU_USAGE" -lt "$MAX_CPU" ] && \
   [ "$USERS" -eq 0 ]; then

    timeout 60s yes > /dev/null &
    dd if=/dev/zero of=/tmp/.oci_keepalive bs=1M count=50 oflag=dsync 2>/dev/null
    rm -f /tmp/.oci_keepalive
    curl -s --max-time 10 https://example.com > /dev/null
fi
EOF

chmod +x /usr/local/bin/keepalive-oci.sh

cat > /etc/systemd/system/keepalive-oci.service << 'EOF'
[Unit]
Description=OCI Keepalive Service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/keepalive-oci.sh
EOF

cat > /etc/systemd/system/keepalive-oci.timer << 'EOF'
[Unit]
Description=Run OCI Keepalive every 10 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=10min
Unit=keepalive-oci.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now keepalive-oci.timer

echo "Keepalive configurado correctamente."