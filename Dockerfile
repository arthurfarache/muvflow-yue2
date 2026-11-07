# YuE2 para a fila de pedidos (Job Queue) da SaladCloud — teste de estabilidade da MuvFlow.
# Só código: os pesos (m-a-p/YuE2-3B, CC BY-NC 4.0) são baixados do Hugging Face quando a máquina liga.
FROM pytorch/pytorch:2.10.0-cuda12.8-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/models/hf \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && python -c "import sys, torch; print(sys.executable, 'torch', torch.__version__, 'cuda', torch.version.cuda)"

RUN pip install --no-cache-dir "huggingface-hub==0.36.2" hf_transfer soundfile "fastapi==0.115.6" "uvicorn==0.32.1"

# Pacote oficial do YuE2. Ele fixa torch 2.10; alinhar torchvision/torchaudio com a mesma versão
# (com versões misturadas o import falha com "operator torchvision::nms does not exist").
RUN hf download m-a-p/YuE2-3B yue2_infer-0.1.5-py3-none-any.whl --local-dir /tmp/w \
    && pip install --no-cache-dir /tmp/w/yue2_infer-0.1.5-py3-none-any.whl \
    && pip uninstall -y torchcodec || true \
    && pip install --no-cache-dir "torchvision==0.25.0" "torchaudio==2.10.0" --index-url https://download.pytorch.org/whl/cu128 \
    && rm -rf /tmp/w \
    && python -c "import torch, torchvision, torchaudio, yue2; print('torch', torch.__version__, torchvision.__version__, torchaudio.__version__)"

# Worker da fila da Salad (pega o pedido da fila e entrega em http://localhost:8000/generate).
ADD https://github.com/SaladTechnologies/salad-cloud-job-queue-worker/releases/download/v0.7.0/salad-http-job-queue-worker_x86_64.tar.gz /tmp/worker.tgz
RUN tar -xzf /tmp/worker.tgz -C /usr/local/bin && rm /tmp/worker.tgz \
    && chmod +x /usr/local/bin/salad-http-job-queue-worker

WORKDIR /app
COPY servidor.py run.sh /app/
RUN chmod +x /app/run.sh
EXPOSE 8000
CMD ["/app/run.sh"]
