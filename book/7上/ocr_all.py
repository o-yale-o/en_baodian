import asyncio
from pathlib import Path
from winrt.windows.media.ocr import OcrEngine
from winrt.windows.graphics.imaging import BitmapDecoder
from winrt.windows.storage.streams import FileRandomAccessStream

async def ocr_file(path):
    stream = await FileRandomAccessStream.open_async(str(path), 0)
    decoder = await BitmapDecoder.create_async(stream)
    bitmap = await decoder.get_software_bitmap_async()
    engine = OcrEngine.try_create_from_user_profile_languages()
    result = await engine.recognize_async(bitmap)
    return result.text

async def main():
    for f in sorted(Path('.').glob('*.jpg')):
        text = await ocr_file(f)
        print(f'=== {f.name} ===')
        print(text)
        print()

asyncio.run(main())
