import io
import os
import base64
import requests
from PIL import Image
import asyncio

# A1111 URL
# url = "http://127.0.0.1:7860"
endpoint = "http://3.113.68.185:8081"

# Read Image in RGB order
# img = cv2.imread("sources/birme-512x512/dog-1.jpeg")

# Encode into PNG and send to ControlNet
# retval, bytes = cv2.imencode('.png', img)
# encoded_image = base64.b64encode(bytes).decode('utf-8')

async def download_image(url: str):
    # response = pipeline_api.run_pipeline(
    #     "pipeline_67d9d8ec36d54c148c70df1f404b0369",
    #     [[image_prompt], {"width": 512, "height": 512, "num_inference_steps": 50}],
    # )
    # image_b64 = response.result_preview[0][0][0]
    print(f"download_image {url}")
    proxies={
        'https':os.getenv('PROXY') 
    }
    response = requests.get(url=url, proxies=proxies)
    ret = response.status_code
    buffer = io.BytesIO(response.content)
    # new_uid = str(uuid.uuid4())
    # buffer.name = new_uid
    return ret, buffer


async def img2img(input_url: str, input_prompt: str =None):
    ret, img_bytes = await download_image(input_url)
    if ret != 200: #fail
        return None
    
    encoded_image = base64.b64encode(img_bytes.getvalue()).decode('utf-8')
    prompt = "(world of warcraft style:1.2),8k,intricate,detailed,master piece"
    if input_prompt is not None:
        prompt = f"{prompt},{input_prompt}"
        print(f"final prompt: {prompt}")

    # A1111 payload
    payload = {
        "init_images": [encoded_image],
        "resize_mode": 0,
        "denoising_strength": 0.75,
        "prompt": prompt,
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
    response = requests.post(url=f'{endpoint}/sdapi/v1/img2img', json=payload)
    # todo，判断结果
    r = response.json()
    # print(r)
    result = r['images'][0]
    buffer = io.BytesIO(base64.b64decode(result.split(",", 1)[0]))

    return buffer


async def __test():
    input_url = "https://cdn.discordapp.com/ephemeral-attachments/1133755737726795888/1133769446654230568/dog-1.jpeg"
    response_buffer = await img2img(input_url, "cure animal")
    if response_buffer == None:
        print("failed")
    else:
        image = Image.open(response_buffer)
        # image.save('output.png')
        image.show()
        print("end")
        

if __name__ == "__main__":
    # response = img2img(input_url)
    # if response.status_code != 200:
    #     print("response failed: {}".format(response.status_code))
    asyncio.run(__test())
    