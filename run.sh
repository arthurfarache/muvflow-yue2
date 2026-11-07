#!/bin/bash
# Sobe o servidor do YuE2 e só liga o worker da fila da Salad quando o modelo está carregado (/health = 200).
# Ligar o worker antes faz ele pedir o token do IMDS cedo demais; sem token, a v0.7.0 realoca a instância
# (perde o download da imagem e dos pesos). Visto no teste de 07/nov/2026.
date -u +%s > /tmp/container_start
echo "$(date -u +%FT%TZ) contêiner iniciou; subindo o servidor"
uvicorn servidor:app --host 0.0.0.0 --port 8000 &
until curl -sf -o /dev/null http://127.0.0.1:8000/health; do sleep 5; done
echo "$(date -u +%FT%TZ) modelo pronto em $(( $(date -u +%s) - $(cat /tmp/container_start) ))s; ligando o worker da fila"
/usr/local/bin/salad-http-job-queue-worker &
wait -n
exit $?
