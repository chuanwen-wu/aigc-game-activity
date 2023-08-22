import os
import io
import os
import base64
import requests
from PIL import Image
import logging
import inference

# Cloud Requirements
import boto3
import json
import requests
import random

REGION = os.environ['REGION']
QUEUE_URL = os.environ['SQSQUEUEURL']
endpoint = os.environ['ENDPOINT']
#REGION = "us-west-2"
#QUEUE_URL = "https://sqs.us-west-2.amazonaws.com/970662323538/discord-diffusion-prod.fifo"
#endpoint = "http://k8s-stabledi-stabledi-c13209743c-1747026568.us-west-2.elb.amazonaws.com"

ssm = boto3.client('ssm', region_name=REGION)
#USER_HG =  ssm.get_parameter(Name='/USER_HG')['Parameter']['Value']
#PASSWORD_HG = ssm.get_parameter(Name='/PASSWORD_HG', WithDecryption=True)['Parameter']['Value']
# Create SQS client
SQS = boto3.client('sqs', region_name=REGION)


WAIT_TIME_SECONDS = 10

### SQS Functions ###
def getSQSMessage(queue_url, time_wait):
    # Receive message from SQS queue
    response = SQS.receive_message(
        QueueUrl=queue_url,
        AttributeNames=[
            'SentTimestamp'
        ],
        MaxNumberOfMessages=1,
        MessageAttributeNames=[
            'All'
        ],
        WaitTimeSeconds=time_wait,
    )

    try:
        message = response['Messages'][0]
    except KeyError:
        return None, None

    receipt_handle = message['ReceiptHandle']
    return message, receipt_handle

def deleteSQSMessage(queue_url, receipt_handle, prompt):
    # Delete received message from queue
    SQS.delete_message(
        QueueUrl=queue_url,
        ReceiptHandle=receipt_handle
    )
    print(f'Received and deleted message: "{prompt}"')

def convertMessageToDict(message):
    cleaned_message = {}
    body = json.loads(message['Body'])
    for item in body:
        # print(item)
        cleaned_message[item] = body[item]['StringValue']
    return cleaned_message

def validateRequest(r):
    if not r.ok:
        print("Failure")
        print(r.text)
        # raise Exception(r.text)
    else:
        print("Success")
    return

### Discord required functions ###
def updateDiscordPicture(application_id, interaction_token, file_path):
    url = f'https://discord.com/api/v10/webhooks/{application_id}/{interaction_token}/messages/@original'
    files = {'stable-diffusion.png': open(file_path,'rb')}
    r = requests.patch(url, files=files)
    validateRequest(r)
    return

def picturesToDiscord(file_path, message_dict, message_response, origin_image_url):
    # Posts a follow up picture back to user on Discord

    # Initial Response is words.
    url = f"https://discord.com/api/v10/webhooks/{message_dict['applicationId']}/{message_dict['interactionToken']}/messages/@original"
    print(url)
    json_payload = {
        "content": f"*Completed your Sparkle!*```{message_response}```",
        "embeds": [{
                    "title": "Origin Image:",
                     "image": {"url": origin_image_url}
                }],
        "attachments": [],
        "allowed_mentions": { "parse": [] },
    }
    r = requests.patch(url, json=json_payload)
    validateRequest(r)

    # Upload a picture
    files = {'stable-diffusion.png': open(file_path,'rb')}
    r = requests.patch(url, json=json_payload, files=files)
    validateRequest(r)

    return

def messageResponse(customer_data):
    message_response = f""
    if 'prompt' in customer_data:
        message_response += f"\nprompt: {customer_data['prompt']}"
    if 'negative_prompt' in customer_data:
        message_response += f"\nNegative Prompt: {customer_data['negative_prompt']}"
    if 'seed' in customer_data:
        message_response += f"\nSeed: {customer_data['seed']}"
    if 'steps' in customer_data:
        message_response += f"\nSteps: {customer_data['steps']}"
    if 'sampler' in customer_data:
        message_response += f"\nSampler: {customer_data['sampler']}"
    return message_response

def submitInitialResponse(application_id, interaction_token, message_response):
    # Posts a follow up picture back to user on Discord
    url = f'https://discord.com/api/v10/webhooks/{application_id}/{interaction_token}/messages/@original'
    print(url)
    json_payload = {
        "content": f"Processing your Sparkle```{message_response}```",
        "embeds": [],
        "attachments": [],
        "allowed_mentions": { "parse": [] },
    }
    r = requests.patch(url, json=json_payload, )
    validateRequest(r)

    return

def cleanupPictures(path_to_file):
    # Clean up file(s) created during creation.
    os.remove(path_to_file)
    return


def decideInputs(user_dict):
    if 'prompt' not in user_dict:
        user_dict['prompt'] = ""
    if 'seed' not in user_dict:
        user_dict['seed'] = random.randint(0,99999)

    if 'steps' not in user_dict:
        user_dict['steps'] = 16

    if 'sampler' not in user_dict:
        user_dict['sampler'] = 'k_euler_a'
    return user_dict

     
def runMain():
    queue_long_poll = WAIT_TIME_SECONDS
    # Get Message from Queue
    while True:
        print("Waiting for next message from Queue...")
        message, receipt_handle = getSQSMessage(QUEUE_URL, WAIT_TIME_SECONDS)

        if not message:
            ## Wait for new message or timeout and exit
            while not message:
                message, receipt_handle = getSQSMessage(QUEUE_URL, queue_long_poll)
                if message:
                    break

        ## Run stable Diffusion
        print("Found a message! Running Stable Diffusion")
        message_dict = convertMessageToDict(message)
        message_dict = decideInputs(message_dict)
        message_response = messageResponse(message_dict)
        print(message_response)
        submitInitialResponse(message_dict['applicationId'], message_dict['interactionToken'], message_response)
        # file_path, user_seed, user_steps = runStableDiffusion(opt, message_dict, model, device, outpath, sampler)
        
        input_prompt=message_dict['prompt']
        origin_image_url=message_dict['image_url']
        response_buffer = inference.img2img(origin_image_url, input_prompt, endpoint)
        if response_buffer == None:
            print("failed")
        else:
            image = Image.open(response_buffer)
            file_path="output.png"
            image.save(file_path)
        #file_path = saveImage(image_list)
        picturesToDiscord(file_path, message_dict, message_response,origin_image_url)
        cleanupPictures(file_path)
        
        ## Delete Message 
        deleteSQSMessage(QUEUE_URL, receipt_handle, message_dict['prompt'])


if __name__ == "__main__":
    runMain()
