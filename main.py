from dotenv import load_dotenv
import os
import logging
from interactions import Client, Intents, listen
from interactions.api.events import Component
from interactions.ext import prefixed_commands
from interactions import OptionType, slash_option
from interactions.models.discord.message import Attachment


load_dotenv()
TOKEN = os.getenv('DISCORD_TOKEN')
PROXY = os.getenv('PROXY')
print(f"TOKEN={TOKEN}, PROXY={PROXY}")

# define your own logger with custom logging settings
logging.basicConfig()
cls_log = logging.getLogger("AgaLogger")
cls_log.setLevel(logging.DEBUG)


bot = Client(intents=Intents.DEFAULT, sync_interactions=True, asyncio_debug=True, logger=cls_log, proxy_url=PROXY)
# intents are what events we want to receive from discord, `DEFAULT` is usually fine
prefixed_commands.setup(bot)

@listen()
async def on_ready():
    print("Ready")
    print(f"This bot is owned by {bot.owner}")


@listen()
async def on_guild_create(event):
    print(f"guild created : {event.guild.name}")


@listen()
async def on_message_create(event):
    print(f"message received: {event.message.content}")


@listen()
async def on_component(event: Component):
    ctx = event.ctx
    await ctx.edit_origin("on_component")

# bot.load_extension("test_components")
# bot.load_extension("test_application_commands")
bot.load_extension("img2img_command")
bot.start(TOKEN)