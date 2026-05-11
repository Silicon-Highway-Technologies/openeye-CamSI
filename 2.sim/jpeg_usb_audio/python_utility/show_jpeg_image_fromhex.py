import re
from encoder import writeJPG_header, writeJPG_footer

def hex_to_jpeg(input_file: str, output_file: str, width: int, height: int, qf: int):
    """
    Converts a text file with hex-encoded JPEG data into a valid JPEG file.
    
    Parameters:
        input_file (str): Path to the input text file containing hex data.
        output_file (str): Path to save the generated JPEG file.
        width (int): Width of the image.
        height (int): Height of the image.
        qf (int): Quality factor for JPEG encoding.
    """
    # Read the file, remove all whitespace, and extract raw hex characters
    with open(input_file, "r") as file:
        content = re.sub(r'/s+', '', file.read())  # Remove spaces, newlines, tabs
    
    # Extract pairs of hex characters (e.g., "FF", "A3", etc.)
    hex_pairs = re.findall(r'[0-9a-fA-F]{2}', content)
    
    # Convert each hex pair to an integer
    data_list = [int(hex_pair, 16) for hex_pair in hex_pairs]
    
    # Construct JPEG file
    hdr = bytearray(writeJPG_header(height=height, width=width, qf=qf))
    ecs = bytearray(data_list)
    ftr = bytearray(writeJPG_footer())
    
    with open(output_file, "wb") as f:
        f.write(hdr)
        f.write(ecs)
        f.write(ftr)
    
    print(f"Wrote image {input_file} to {output_file}")

# # Example usage
# if __name__ == "__main__":
#     for i in range(1, 6):
#         hex_to_jpeg(
#             input_file=f"../image_files/txts/christmas_bits_out_{i}.txt",
#             output_file=f"../image_files/output_jpeg/christmas_out{i}.jpg",
#             width=1280,
#             height=720,
#             qf=100
#         )


hex_to_jpeg(
    # input_file="../image_files/txts/seagulls_encoded_original.txt",
    input_file="../image_files/txts/seagulls_encoded_1.txt",    
    output_file="../image_files/output_jpeg/seagulls_dump.jpg",
    width=1280,
    height=720,
    qf=10
)

# hex_to_jpeg(
#     # input_file="../image_files/txts/seagulls_encoded_original.txt",
#     input_file="../image_files/txts/horses_encoded_3.txt",    
#     output_file="../image_files/output_jpeg/horses_dump.jpg",
#     width=1920,
#     height=1080,
#     qf=50
# )

