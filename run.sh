#!/bin/bash
# Sobe o servidor do YuE2 e, quando a porta responde, o worker da fila da Salad.
# O worker só pega pedidos depois que o readiness probe (/health) passa, isto é, com o modelo carregado.
date -u +%s > /tmp/container_start
uvicorn servidor:app --host 0.0.0.0 --port 8000 &
until (echo > /dev/tcp/127.0.0.1/8000) 2>/dev/null; do sleep 1; done
/usr/local/bin/salad-http-job-queue-worker &
wait -n
exit $?
