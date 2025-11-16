# Piper TTS Training/Fine-Tuning

This repository intends to facilitate the process of training a custom text-to-speech (TTS) model using [Piper TTS](https://github.com/OHF-Voice/piper1-gpl). The workflow assumes a single-speaker and a pretrained checkpoint for fine-tuning.

## Pre-requisites

Clone this repository:

```console
git clone https://github.com/veralvx/piper-train
```

Prepare files for training:

- Dataset with WAV audio files (mono, 22050 Hz) in `./wavs` 

- `metadata.csv`file  in `./metadata`, formatted as `file|text` (e.g., `001|This is a test.`). You may use [Trainscribe](https://github.com/veralvx/trainscribe) for this.

- Pretrained checkpoint (e.g., `en_US-lessac-medium.ckpt` in `./checkpoints`) for fine-tuning. you must obtain a checkpoint from [Hugging Face](https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main). For example, obtain `epoch=2164-step=1355540.ckpt` from https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main/en/en_US/lessac/medium and move it to `./checkpoints/en_US-lessac-medium.ckpt`


All of the Python and system dependencies are already set up in the Dockerfile. 

Build: 

```console
podman build -f Dockerfile -t piper-train
```

Run (command also available in `podman.sh`): 

```console
podman run -it --rm \
  --gpus=all \
  --network=none \
  --shm-size=1g \
  -v ./wavs:/piper/wavs \
  -v ./metadata:/piper/metadata \
  -v ./checkpoints:/piper/checkpoints \
  -v ./lightning_logs:/piper/lightning_logs \
  piper-train
```


Note: If you are not using CUDA, you must replace `--index https://download.pytorch.org/whl/cu124` with the correct Pytorch (version 2.5) URL for your system (https://pytorch.org/get-started/previous-versions/) in the `Dockerfile`.



### Training

All the commands in this section must run inside the container.

Intermediate checkpoints will be saved in `lightning_logs`.

Adjust the following parameters as needed:

- `--data.voice_name`
- `--data.espeak_voice`
- `--data.batch_size`
- `--trainer.max_epochs`
- `--ckpt_path`

#### Training with Validation Loss Monitoring

This variant monitors `val_loss` to save the best checkpoint based on this parameter.

```
uv run python3 -m piper.train fit \
  --data.voice_name "speaker" \
  --data.csv_path ./metadata/metadata.csv \
  --data.audio_dir ./wavs \
  --model.sample_rate 22050 \
  --data.espeak_voice "en" \
  --data.cache_dir ./cache \
  --data.config_path ./checkpoints/config.json \
  --data.batch_size 32 \
  --trainer.max_epochs 3200 \
  --trainer.callbacks lightning.pytorch.callbacks.ModelCheckpoint \
  --trainer.callbacks.monitor val_loss \
  --trainer.callbacks.mode min \
  --trainer.callbacks.save_top_k 1 \
  --trainer.callbacks.save_last true \
  --trainer.callbacks.dirpath ./checkpoints \
  --trainer.callbacks.filename "best-epoch={epoch}-{val_loss:.2f}" \
  --trainer.callbacks.every_n_epochs 1 \
  --ckpt_path ./checkpoints/en_US-lessac-medium.ckpt
```

#### Training without Monitoring

Saves checkpoints periodically without validation tracking.

```
uv run python3 -m piper.train fit \
  --data.voice_name "speaker" \
  --data.csv_path ./metadata/metadata.csv \
  --data.audio_dir ./wavs \
  --model.sample_rate 22050 \
  --data.espeak_voice "pt" \
  --data.cache_dir ./cache \
  --data.config_path ./checkpoints/config.json \
  --data.batch_size 1 \
  --trainer.max_epochs 3200 \
  --trainer.callbacks "lightning.pytorch.callbacks.ModelCheckpoint" \
  --trainer.callbacks.every_n_epochs 50 \
  --trainer.callbacks.save_top_k -1 \
  --trainer.callbacks.monitor null \
  --trainer.callbacks.dirpath ./checkpoints \
  --trainer.callbacks.filename "epoch={epoch}-step={step}" \
  --ckpt_path ./checkpoints/en_US-lessac-medium.ckpt
```

### Export to ONNX

Convert the resulting checkpoint (adjust the name for `--checkpoint` as needed) to ONNX for inference. The pattern for `--output-file` name is `langCode-speakerName-quality.onnx`.

```
uv run python3 -m piper.train.export_onnx \
  --checkpoint ./checkpoints/checkpoint.ckpt \
  --output-file ./checkpoints/en_US-speaker-medium.onnx
```

Then, rename `./checkpoints/config.json` to the same base name as the `onnx` file. For example, `./checkpoints/en_US-speaker-medium.json`.
 
### Inference

Synthesize speech from text using the ONNX model.

```
uv run python3 -m piper -m ./checkpoints/en_US-speaker-medium.onnx -f ./checkpoints/test.wav -- 'This is a test.'
```
