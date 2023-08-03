#!/bin/bash

function init() {
    models_list=("models/Stable-diffusion/rpg_V4.safetensors" "models/ControlNet/control_v11p_sd15_canny.pth")
    for f in ${models_list[@]}
    do
        echo $f
        to=./stable-diffusion-webui/$f
        from="s3://sagemaker-ap-northeast-1-733851053666/stable-diffusion-webui/${f}"
        if [[ ! -f $to ]]; then 
            echo "${to} not exist"; 
            time s5cmd cp $from $to ;
        fi
    done;
}

init
cd stable-diffusion-webui/
ACCELERATE=true bash ./webui.sh -f --api --listen --port 8080 --xformers --enable-insecure-extension-access

# ACCELERATE=true bash ./webui.sh -f --api --listen --port 8080 --xformers --enable-insecure-extension-access
