#!/bin/bash

inference_image=sd-game-activty
datadir=/home/ubuntu/stable-diffusion-webui/models
docker run --runtime=nvidia --gpus all --rm \
    -p 8080:8080 \
    -v ${datadir}/Stable-diffusion:/app/stable-diffusion-webui/models/Stable-diffusion \
    -v ${datadir}/Lora:/app/stable-diffusion-webui/models/Lora \
    -v ${datadir}/ControlNet:/app/stable-diffusion-webui/models/ControlNet \
    ${inference_image}:latest 

# docker run --gpus all --rm \
#     -p 8081:8080 \
#     -v /home/ubuntu/sd-docker/datadir/extensions:/app/stable-diffusion-webui/extensions \
#     -v /home/ubuntu/sd-docker/datadir/models:/app/stable-diffusion-webui/models \
#     -v /home/ubuntu/sd-docker/datadir/outputs:/app/stable-diffusion-webui/outputs \
#     -v /home/ubuntu/sd-docker/datadir/localizations:/app/stable-diffusion-webui/localizations \
#     -v /home/ubuntu/sd-docker/datadir/trainings:/app/stable-diffusion-webui/trainings \
#     -v /home/ubuntu/sd-docker/datadir/repositories:/app/stable-diffusion-webui/repositories \
#     -v /home/ubuntu/sd-docker/datadir/embeddings:/app/stable-diffusion-webui/embeddings \
#     ${inference_image}:latest 
