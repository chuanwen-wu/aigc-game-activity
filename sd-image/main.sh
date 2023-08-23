#!/bin/bash

function init() {
    echo $(date) "init..."    
    models_list=("models/Stable-diffusion/rpg_V4.safetensors" "models/ControlNet/control_v11p_sd15_canny.pth")
    for f in ${models_list[@]}
    do
        # echo $f
        to=./stable-diffusion-webui/$f
        from="s3://sagemaker-ap-northeast-1-733851053666/stable-diffusion-webui/${f}"
        if [[ ! -f $to ]]; then 
            echo "${to} not exist, downloading..."; 
            time s5cmd cp $from $to ;
        fi
    done;
}

appendArgs=''
echo ckpt_dir=$ckpt_dir
if [[ ! "" == $ckpt_dir ]]; then
    appendArgs="${appendArgs} --ckpt-dir=${ckpt_dir} --ckpt=${ckpt_dir}/rpg_V4.safetensors"
fi

if [[ ! "" == $lora_dir ]]; then
    appendArgs="${appendArgs} --lora-dir=${lora_dir}"
fi

if [[ ! "" == $controlnet_dir ]]; then
    appendArgs="${appendArgs} --controlnet-dir=${controlnet_dir}"
fi

echo "auto_exit=$auto_exit"
if [[ $auto_exit ]]; then
    appendArgs="${appendArgs} --exit"
fi
# echo appendArgs=${appendArgs}

# init
cd stable-diffusion-webui/
echo "$(date) -- ACCELERATE=true bash ./webui.sh -f --api --listen --port 8080 --xformers --enable-console-prompts --api-log --skip-version-check --skip-torch-cuda-test --no-download-sd-model ${appendArgs}"
ACCELERATE=true bash ./webui.sh -f --api --listen --port 8080 --xformers --enable-console-prompts --api-log --skip-version-check --skip-torch-cuda-test --no-download-sd-model ${appendArgs}
