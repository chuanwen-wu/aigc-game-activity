import requests
from PIL import Image, PngImagePlugin
import io
import base64
import pprint
import sys

# url = "http://127.0.0.1:7860"
url = "http://3.113.68.185:8080"

model_list = [
    'v1-5-pruned.ckpt [e1441589a6]',
    'chilloutmix_NiPrunedFp32.safetensors [95afa0d9ea]'
]

params = {
        # "sd_model_checkpoint": "v1-5-pruned.ckpt [e1441589a6]",
        'enable_hr': False, 
        'denoising_strength': 0.7, 
        'firstphase_width': 0, 
        'firstphase_height': 0, 
        "prompt": "a dog",
        # 'negative_prompt': "(worst quality:2), (low quality:2), (normal quality:2), normal quality, ((monochrome)), ((grayscale)), skin spots, acnes, skin blemishes, age spot, backlight,(ugly:1.331), (duplicate:1.331), (morbid:1.21), (mutilated:1.21), (tranny:1.331), deformed eyes, deformed lips, mutated hands, (poorly drawn hands:1.331), blurry, (bad anatomy:1.21), (bad proportions:1.331), three arms, extra limbs, extra legs, extra arms, extra hands, (more than 2 nipples:1.331), (missing arms:1.331), (extra legs:1.331), (fused fingers:1.61051), (too many fingers:1.61051), (unclear eyes:1.331), bad hands, missing fingers, extra digit, (futa:1.1), bad body, pubic hair, glans, easynegative, three feet, four feet, nsfw, naked, nude, unequal eyes, (close up:2), untracked eyes, crossed eyes", 
        'negative_prompt': "",
        'sampler_index': 'Euler a', 
        'batch_size': 1, 
        'steps': 20, 
        'cfg_scale': 7, 
        'width': 512, 
        'height': 512, 
        'seed': 2354492891, 
        'subseed': -1.0, 
        'subseed_strength': 0, 
        'seed_resize_from_h': 0, 
        'seed_resize_from_w': 0, 
        'n_iter': 1, 
        'restore_faces': False, 
        'tiling': False, 
        'eta': 1, 
        's_churn': 0, 
        's_tmax': None, 
        's_tmin': 0, 
        's_noise': 1, 
        'override_settings': {}, 
        'script_args': [0, False, False, False, "", 1, "", 0, "", True, False, False],
    }
override_settings = {}
if len(sys.argv) >= 2 and sys.argv[1] == "model1":    #
    override_settings["sd_model_checkpoint"] = model_list[1]
else:
    override_settings["sd_model_checkpoint"] = model_list[0]

override_payload = {
                "override_settings": override_settings
            }
params.update(override_payload)
print(params)

def create_pic():
    response = requests.post(url=f'{url}/sdapi/v1/txt2img', json=params)
    return response

def parse_response(response):
    r = response.json()  # convert result to json
    for i in r['images']:
        image = Image.open(io.BytesIO(base64.b64decode(i.split(",",1)[0])))
        image.show()
        # png_payload = {
        #     "image": "data:image/png;base64," + i
        # }
        # response2 = requests.post(url=f'{url}/sdapi/v1/png-info', json=png_payload)

        # pnginfo = PngImagePlugin.PngInfo()
        # pnginfo.add_text("parameters", response2.json().get("info"))
        # image.save('output.png', pnginfo=pnginfo)

if __name__ == "__main__":
    response = create_pic()
    if response.status_code != 200:
        print("response failed: {}".format(response.status_code))

    # print(response.json())    
    parse_response(response)
    pass
