import re
import sys
import os

def load_hex_as_string(filepath):
    """Reads a file, cleans formatting, and returns a pure lowercase hex string."""
    if not os.path.exists(filepath):
        return ""
    
    with open(filepath, 'r') as f:
        raw_text = f.read()
        # Strip out "0x" or "0X" prefixes if they exist
        raw_text = raw_text.replace('0x', '').replace('0X', '')
        # Remove absolutely everything that is not a valid hex character
        clean_text = re.sub(r'[^0-9a-fA-F]', '', raw_text)
        # Convert to lowercase to ensure perfect matching
        return clean_text.lower()

def process_dump(data_file, header_file, footer_file, output_file):
    print("[*] Loading files...")
    data = load_hex_as_string(data_file)
    header = load_hex_as_string(header_file)
    footer = load_hex_as_string(footer_file)

    if not data:
        print("[!] FATAL ERROR: Main data file is empty or missing.")
        sys.exit(1)

    start_idx = 0
    end_idx = len(data)

    # 1. STRIP THE HEADER
    if header:
        idx = data.find(header)
        if idx == -1:
            print("[!] FATAL ERROR: The exact header sequence was NOT found.")
            sys.exit(1)
        
        print(f"[+] Header verified. Stripping {len(header)} characters...")
        start_idx = idx + len(header)
    else:
        print("[-] No header defined in headers.txt. Skipping.")

    # 2. STRIP THE FOOTER
    if footer:
        # Search for the footer ONLY in the data after the header
        idx = data.find(footer, start_idx)
        if idx == -1:
            print("[!] FATAL ERROR: The exact footer sequence was NOT found.")
            sys.exit(1)
            
        print(f"[+] Footer verified. Stripping from the end...")
        end_idx = idx
    else:
        print("[-] No footer defined in footers.txt. Skipping.")

    # 3. EXTRACT CORE PAYLOAD
    core_hex = data[start_idx:end_idx]

    # 4. FORMAT TO 8 CHARS PER ROW
    # Slices the giant string into chunks of 8 characters
    formatted_lines = [core_hex[i:i+8] for i in range(0, len(core_hex), 8)]

    # 5. WRITE TO TEXT FILE
    with open(output_file, 'w') as f:
        for line in formatted_lines:
            f.write(line + '\n')
    
    print(f"\n[+] SUCCESS! Wrote {len(formatted_lines)} formatted rows to {output_file}")

if __name__ == "__main__":
    # Define your filenames here
    DATA_TXT = "../../../3.build/vivado/vivado.sim/sim_1/behav/xsim/continuous_capture_usb_jpeg.txt"
    HEADER_TXT = "../../../1.hw/usb/mem/headers_720p_qf50.mem"
    FOOTER_TXT = "../../../1.hw/usb/mem/footers.mem"
    OUTPUT_TXT = "core_data.txt"

    process_dump(DATA_TXT, HEADER_TXT, FOOTER_TXT, OUTPUT_TXT)