from interactions import slash_command, slash_option, SlashContext, context_menu, CommandType, Button, ActionRow, ButtonStyle, Extension, OptionType
from interactions.models.discord.message import Attachment
import interactions
import traceback
import inference
from interactions.models import *

class Img2imgCommands(Extension):
    @slash_command(name="img2img", description="图生图", scopes=[1134099955469013102])
    @slash_option(name="image", description="Your Image", required=True, opt_type=OptionType.ATTACHMENT)
    @slash_option(name="prompt", description="Your Prompt", required=False, opt_type=OptionType.STRING)
    async def command(self, ctx: SlashContext, image: Attachment, prompt: str=""):
        # need to defer it, otherwise, it fails
        await ctx.defer()
        print(f"input image url={image.url}, input prompt={prompt}")
        # print(image.filename)
        sent_response = await ctx.send("Generating image...")

        try:
            image_buffer = await inference.img2img(image.url, prompt)
            # Edit the original message sent to now include the image and the prompt
            await sent_response.edit(
                files = [
                    interactions.models.discord.File(
                        file_name=image.filename, file=image_buffer
                    ),
                    # interactions.models.discord.File(
                    #     file_name=image.filename, file=image_buffer2
                    # )
                ],
                content="Result: ",
                # You can add another argument 'ephemeral=True' to only show the 
                # result to the user that sent the request.
                embeds = [
                    Embed(title=f"Origin: {prompt}", 
                        images=[
                            EmbedAttachment(url=image.url),
                        ]
                    )
                ]
            )
        except:
            # If the image generation (or anything else) fails 
            # for any reason it's best to let the user know
            await sent_response.edit(
                content="Generation failed, please try again!",
            )

            # With asyncio you have to call the 'flush=True' on print
            print(traceback.format_exc(), flush=True)

        # do stuff for a bit
        # await asyncio.sleep(3)
        # await ctx.send("Hello World")
        # print("[end]")

    @command.error
    async def command_error(self, e, *args, **kwargs):
        print(f"Command hit error with {args=}, {kwargs=}")

    @command.pre_run
    async def command_pre_run(self, context, *args, **kwargs):
        print("I ran before the command did!")


def setup(bot):
    # inference.hello()
    Img2imgCommands(bot)
