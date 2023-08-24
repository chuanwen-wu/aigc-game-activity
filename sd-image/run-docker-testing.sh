#!/bin/bash

# inference_image=sd-game-activity:latest
inference_image=sd-game-activity:0.23-committed
datadir=/home/ubuntu/datadir/models
docker run --runtime=nvidia --gpus all --rm \
    -p 8080:8080 \
    -v ${datadir}:/app/datadir \
    -e ckpt_dir=/app/datadir/Stable-diffusion \
    -e lora_dir=/app/datadir/Lora \
    -e controlnet_dir=/app/datadir/ControlNet \
    ${inference_image}
