"""Servidor do YuE2 para a fila da SaladCloud (teste de estabilidade da MuvFlow).

GET  /health    200 quando o modelo está carregado (readiness probe); 503 antes.
POST /generate  {id, style, lyrics, seed, cot} → gera uma música e devolve só medidas (o áudio é descartado
                neste teste: o que se mede é velocidade, queda de máquina e partida, não qualidade).
"""
import hashlib
import os
import tempfile
import threading
import time

import soundfile as sf
import torch
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel

INICIO_CONTAINER = float(open("/tmp/container_start").read()) if os.path.exists("/tmp/container_start") else time.time()
estado = {"pronto": False, "carga_s": None, "download_s": None, "feitos": 0, "erro_carga": None}
trava = threading.Lock()
pipe = None
app = FastAPI()


def carregar():
    global pipe
    try:
        from huggingface_hub import snapshot_download
        t = time.time()
        snapshot_download("m-a-p/YuE2-3B")
        snapshot_download("m-a-p/YuE2-Vae")
        estado["download_s"] = round(time.time() - t, 1)
        from yue2 import YuE2Pipeline
        t = time.time()
        pipe = YuE2Pipeline.from_pretrained("m-a-p/YuE2-3B", device="cuda", progress=False)
        estado["carga_s"] = round(time.time() - t, 1)
        estado["pronto"] = True
    except Exception as e:  # sem modelo, o /health nunca passa e a Salad recria a instância
        estado["erro_carga"] = repr(e)[:500]


threading.Thread(target=carregar, daemon=True).start()


class Pedido(BaseModel):
    id: str
    style: str
    lyrics: str
    seed: int = 20261106
    cot: str = "full"


@app.get("/health")
def health():
    if estado["pronto"]:
        return {"ok": True}
    return JSONResponse({"ok": False, **estado}, status_code=503)


@app.post("/generate")
def generate(p: Pedido):
    with trava:  # uma música por vez por GPU (rodar em paralelo não rende: medido em 06/nov)
        torch.cuda.reset_peak_memory_stats()
        torch.cuda.synchronize()
        t = time.time()
        song = pipe(style=p.style, lyrics=p.lyrics, cot=p.cot, seed=p.seed)
        torch.cuda.synchronize()
        seg = time.time() - t
        with tempfile.NamedTemporaryFile(suffix=".flac") as f:
            song.save(f.name)
            info = sf.info(f.name)
            dur = info.frames / info.samplerate
            sha = hashlib.sha256(open(f.name, "rb").read()).hexdigest()[:16]
        estado["feitos"] += 1
        return {
            "id": p.id, "seed": p.seed, "segundos_geracao": round(seg, 2), "segundos_audio": round(dur, 2),
            "razao": round(seg / dur, 3) if dur else None, "pico_vram_gib": round(torch.cuda.max_memory_allocated() / 2**30, 2),
            "gpu": torch.cuda.get_device_name(0), "maquina": os.environ.get("SALAD_MACHINE_ID"),
            "instancia_uptime_s": round(time.time() - INICIO_CONTAINER), "feitos_nesta_instancia": estado["feitos"],
            "download_pesos_s": estado["download_s"], "carga_modelo_s": estado["carga_s"], "sha256_16": sha,
        }
