import io
import cv2
import base64
import requests
import time
from PIL import Image


# A1111 URL
# url = "http://127.0.0.1:7860"
url = "http://k8s-default-mysd-c832f10821-315108241.ap-northeast-1.elb.amazonaws.com"
# url = "http://3.113.68.185:8080"

# Read Image in RGB order
img = cv2.imread("assets/dog-1.jpeg")
# img = cv2.imread("sources/birme-512x512/woman-1.jpeg")

# Encode into PNG and send to ControlNet
retval, bytes = cv2.imencode('.png', img)
encoded_image = base64.b64encode(bytes).decode('utf-8')

# A1111 payload
payload = {
    # "prompt": 'a dog',
    # "negative_prompt": "",
    # "batch_size": 1,
    # "steps": 20,
    # "cfg_scale": 7,
    "init_images": [encoded_image],
    "resize_mode": 0,
    "denoising_strength": 0.75,
    "prompt": "(world of warcraft style:1.2),8k,intricate,detailed,master piece",
    "negative_prompt": "nsfw",
    "subseed_strength": 0,
    # 'seed': 1434960243, 
    "seed": -1,
    "seed_resize_from_h": -1,
    "seed_resize_from_w": -1,
    "sampler_name": "Euler a",
    "batch_size": 1,
    "steps": 20,
    "cfg_scale": 7,
    "width": 512,   
    "height": 512,
    "restore_faces": False,
    "sampler_index": "Euler a",
    "script_name": "",
    "send_images": True,
    "save_images": False,
    "alwayson_scripts": {
        "controlnet": {
            "args": [
                {
                    # "input_image": encoded_image,
                    "image": encoded_image,
                    "module": "canny",
                    "model": "control_v11p_sd15_canny [d14c016b]",
                    "processor_res": 512,
                    "threshold_a": 100,
                    "threshold_b": 200,
                    "control_mode": "ControlNet is more important"
                }
            ]
        }
    }
}


# Trigger Generation
response = requests.post(url=f'{url}/sdapi/v1/img2img', json=payload)

# Read results
r = response.json()
# print(r)
result = r['images'][0]
image = Image.open(io.BytesIO(base64.b64decode(result.split(",", 1)[0])))
f = "./outputs/{}.jpg".format(time.time())
image.save(f)
# image.show()