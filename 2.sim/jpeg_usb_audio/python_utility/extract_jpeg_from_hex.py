import re
import sys
import os

def load_hex_as_bytes(filepath):
    """Reads a file, aggressively cleans formatting, and returns raw bytes."""
    if not os.path.exists(filepath):
        return b""
    
    with open(filepath, 'r') as f:
        raw_text = f.read()
        raw_text = raw_text.replace('0x', '').replace('0X', '')
        clean_text = re.sub(r'[^0-9a-fA-F]', '', raw_text)
        return bytes.fromhex(clean_text)

def process_image(data_file, header_file, footer_file, output_file):
    print("[*] Loading files...")
    data = load_hex_as_bytes(data_file)
    header = load_hex_as_bytes(header_file)
    footer = load_hex_as_bytes(footer_file)

    if not data:
        print("[!] FATAL ERROR: Main data file is empty or missing.")
        sys.exit(1)

    start_idx = 0
    end_idx = len(data)

    # 1. SMART HEADER CHECK
    if header:
        idx = data.find(header)
        if idx == -1:
            print("[!] FATAL ERROR: The exact header sequence was NOT found.")
            sys.exit(1)
        
        print(f"[+] Header verified at byte {idx}.")
        
        # If your header *is* the start of the JPEG, we MUST keep it.
        if header.startswith(b'\xff\xd8'):
            print("    -> Header starts with FF D8 (JPEG Start). Keeping it in the image.")
            start_idx = idx
        else:
            print("    -> Header is a custom wrapper. Stripping it from the image.")
            start_idx = idx + len(header)
    else:
        print("[-] No header defined in headers.txt. Skipping.")

    # 2. SMART FOOTER CHECK
    if footer:
        idx = data.find(footer, start_idx)
        if idx == -1:
            print("[!] FATAL ERROR: The exact footer sequence was NOT found.")
            sys.exit(1)
            
        print(f"[+] Footer verified at byte {idx}.")
        
        # If your footer *is* the end of the JPEG, we MUST keep it.
        if footer.endswith(b'\xff\xd9'):
            print("    -> Footer ends with FF D9 (JPEG End). Keeping it in the image.")
            end_idx = idx + len(footer)
        else:
            print("    -> Footer is a custom wrapper. Stripping it from the image.")
            end_idx = idx
    else:
        print("[-] No footer defined in footers.txt. Skipping.")

    # 3. EXTRACT PAYLOAD
    jpeg_payload = data[start_idx:end_idx]

    # 4. FINAL SANITY CHECK
    if not jpeg_payload.startswith(b'\xff\xd8'):
        print("\n[!] WARNING: The final extracted payload STILL doesn't start with FF D8!")
        print("    Your resulting JPEG will likely be invalid.")
    
    if not jpeg_payload.endswith(b'\xff\xd9'):
        print("\n[!] WARNING: The final extracted payload DOES NOT end with FF D9!")
        print("    The image might be cut off at the bottom.")

    # 5. SAVE TO DISK
    with open(output_file, 'wb') as f:
        f.write(jpeg_payload)
    
    print(f"\n[+] SUCCESS! Wrote {len(jpeg_payload)} bytes to {output_file}")

if __name__ == "__main__":
    # Define your filenames here
    DATA_TXT = "../../../3.build/vivado/vivado.sim/sim_1/behav/xsim/continuous_capture_usb_jpeg.txt"
    HEADER_TXT = "../../../1.hw/usb/mem/headers_720p_qf50.mem"
    FOOTER_TXT = "../../../1.hw/usb/mem/footers.mem"
    OUTPUT_JPG = "output.jpg"

    process_image(DATA_TXT, HEADER_TXT, FOOTER_TXT, OUTPUT_JPG)