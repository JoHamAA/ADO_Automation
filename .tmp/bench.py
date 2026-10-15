import io, time, threading
from concurrent.futures import ThreadPoolExecutor
from PIL import Image, ImageDraw
from tag_inheritance import image_tags
im = Image.new('RGB', (1280, 800), 'white'); d = ImageDraw.Draw(im)
for i in range(30): d.text((20, 20 + i * 25), 'Mutation test line %d with some more words here' % i, fill='black')
b = io.BytesIO(); im.save(b, 'PNG'); data = b.getvalue()
def bench(workers, threads):
    image_tags._OCR_LOCAL = threading.local()
    image_tags.OCR_THREADS = threads
    with ThreadPoolExecutor(workers) as p:
        list(p.map(image_tags.ocr_image, [data] * workers * 3))
        t = time.perf_counter()
        list(p.map(image_tags.ocr_image, [data] * 16))
        return round(time.perf_counter() - t, 1)
print('1 worker, default threads', bench(1, 0), flush=True)
print('2 workers x 8 threads', bench(2, 8), flush=True)
print('4 workers x 4 threads', bench(4, 4), flush=True)
print('6 workers x 3 threads', bench(6, 3), flush=True)
