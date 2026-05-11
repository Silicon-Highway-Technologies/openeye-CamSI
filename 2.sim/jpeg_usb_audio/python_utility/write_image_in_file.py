import PIL
from PIL import Image

# Load a bmp image and write its components in a txt file
# each line of the txt file has three integers (0-255) corresponding to R G B of each pixel
def write_image_in_file(image_path, output_file_path):
    
    img = Image.open(image_path)
    img = img.convert("RGB")

    width, height = img.size

    with open(output_file_path, "w") as output_file:
        for y in range(height):
            for x in range(width):
                r, g, b = img.getpixel((x, y))
                
                output_file.write(str(r) + ' ' + str(g) + ' ' + str(b) + '\n')

    print(f"Image data has been written to {output_file_path}")

image_path = '../image_files/original_bmp/horses.bmp'
output_file_path = '../image_files/txts/horses_original.txt'

write_image_in_file(image_path, output_file_path)