FROM nvidia/cuda:12.9.1-cudnn-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH="/usr/local/bin:/root/.local/bin:/root/bin:/piper/.venv/bin:${PATH}"


RUN apt-get update && apt upgrade -y && apt-get install -y --no-install-recommends \
    bash coreutils vim nano \
    git curl wget ca-certificates gnupg \
    build-essential pkg-config ninja-build cmake \
    python3 python3-pip python3-venv python3-dev \
    ffmpeg espeak-ng \
    && rm -rf /var/lib/apt/lists/*


COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
RUN chmod +x /usr/local/bin/uv

WORKDIR /piper
RUN git clone --depth 1 --branch v1.3.0 https://github.com/OHF-voice/piper1-gpl.git .
RUN if ! [ -d wavs ]; then mkdir wavs; fi && if ! [ -d metadata ]; then mkdir metadata; fi && if ! [ -d checkpoints ]; then mkdir checkpoints; fi && if ! [ -d lightning_logs ]; then mkdir lightning_logs; fi && if ! [ -d cache ]; then mkdir cache; fi
RUN uv python install 3.13 && uv python pin 3.13 && uv venv .venv --python 3.13

RUN uv pip install -e .[train] torch==2.5.1 lightning==2.1.0 numpy "ml_dtypes>=0.5.0" scikit-build \
    --index https://download.pytorch.org/whl/cu124 \
    --index https://pypi.org/simple \
    --index-strategy=unsafe-best-match \
    --compile-bytecode


RUN uv run python3 setup.py build_ext --inplace
RUN . .venv/bin/activate && ./build_monotonic_align.sh
ENV UV_OFFLINE=1