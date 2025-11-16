podman run -it --rm \
  --gpus=all \
  --network=none \
  --shm-size=1g \
  -v ./wavs:/piper/wavs \
  -v ./metadata:/piper/metadata \
  -v ./checkpoints:/piper/checkpoints \
  -v ./lightning_logs:/piper/lightning_logs \
  piper-train
