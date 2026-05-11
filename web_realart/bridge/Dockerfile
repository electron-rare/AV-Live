FROM python:3.12-slim

WORKDIR /app

# Pas de pose (YOLO) en prod headless : on n'installe pas opencv/ultralytics.
RUN pip install --no-cache-dir \
    "python-osc>=1.8.3" \
    "httpx>=0.27" \
    "websockets>=12.0" \
    "aiomqtt>=2.3" \
    "skyfield>=1.49"

# Copie le code source du bridge depuis le repo (build context = ./bridge,
# mais on a besoin du code de ../../data_feeds : on copie via build.sh
# OU on monte en volume. Plus simple : sync via build.sh avant docker compose).
# Code source du bridge (synchronise depuis ../../data_feeds via build.sh)
COPY src/bridge.py /app/bridge.py
COPY src/feeds /app/feeds

# config.toml fourni en volume read-only par compose
CMD ["python", "bridge.py", "--config", "/app/config.toml"]
