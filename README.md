# muvflow-yue2

Worker do [YuE2](https://huggingface.co/m-a-p/YuE2-3B) para a fila de pedidos (Job Queue) da SaladCloud, usado no teste de estabilidade da MuvFlow.

- `servidor.py`: FastAPI; carrega o modelo uma vez; `GET /health` (readiness), `POST /generate` (uma música por vez, devolve medidas).
- `run.sh`: sobe o servidor e o `salad-http-job-queue-worker` (v0.7.0).
- A imagem contém só código. Os pesos do YuE2 (CC BY-NC 4.0, m-a-p) são baixados do Hugging Face quando a máquina liga; não são redistribuídos aqui.
- Construída pelo GitHub Actions em `ghcr.io/arthurfarache/muvflow-yue2`.
