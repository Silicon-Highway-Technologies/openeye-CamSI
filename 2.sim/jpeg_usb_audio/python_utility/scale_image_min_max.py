import PIL
from PIL import Image

# Scale a pixel according to the specified minimum and maximum values
def scalepixel(pixelvalue, oldmin, oldmax, newmin, newmax):
  olddiff = oldmax - oldmin
  newdiff = newmax - newmin

  ratio = (pixelvalue - oldmin) / olddiff

  newpixelvalue = ratio*newdiff + newmin

  return int(newpixelvalue)

# Read the pixels of an image
def read_pixel_data(input_file_path):
    pixel_data = []
    with open(input_file_path, 'r') as file:
        for line in file:
            try:
                r, g, b = map(int, line.strip().split())
                pixel_data.append((r, g, b))
            except ValueError:
                print(f"Invalid line in pixel data file: {line.strip()}")
    return pixel_data

input_file_path = "../image_files/txts/horses_original.txt"
pixel_data = read_pixel_data(input_file_path)

newminred, newmingreen, newminblue = 0, 200, 0
newmaxred, newmaxgreen, newmaxblue = 255, 230, 255

output_file_path = "../image_files/txts/horses_scaled.txt"

height = 1920
width = 1080

with open(output_file_path, "w") as output_file:
  for x in range(0, height*width):

    r = pixel_data[x][0]
    g = pixel_data[x][1]
    b = pixel_data[x][2]

    newr = scalepixel(r, 0, 255, newminred, newmaxred)
    newg = scalepixel(g, 0, 255, newmingreen, newmaxgreen)
    newb = scalepixel(b, 0, 255, newminblue, newmaxblue)
    
    output_file.write(str(newr) + ' ' + str(newg) + ' ' + str(newb) + '\n')

print(f"Image data has been written (scaled) to {output_file_path}")
