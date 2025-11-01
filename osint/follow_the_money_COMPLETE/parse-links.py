import os
import re
import email
from email import policy
from email.parser import BytesParser
from urllib.parse import unquote
from pathlib import Path

def extract_urls_from_text(text):
    """Extract URLs from text using regex patterns."""
    if not text:
        return set()
    
    # Common URL patterns
    url_patterns = [
        r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+',
        r'www\.(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+',
    ]
    
    urls = set()
    for pattern in url_patterns:
        matches = re.findall(pattern, text, re.IGNORECASE)
        urls.update(matches)
    
    return urls

def decode_url(url):
    """Decode URL-encoded strings."""
    try:
        # Decode URL encoding (e.g., %20 for space)
        decoded = unquote(url)
        return decoded
    except:
        return url

def extract_links_from_eml(eml_path):
    """Extract all links from an .eml file."""
    links = set()
    
    try:
        with open(eml_path, 'rb') as f:
            msg = BytesParser(policy=policy.default).parse(f)
        
        # Extract from all parts of the email
        if msg.is_multipart():
            for part in msg.walk():
                content_type = part.get_content_type()
                
                # Get the content
                try:
                    if content_type == 'text/plain' or content_type == 'text/html':
                        payload = part.get_content()
                        urls = extract_urls_from_text(payload)
                        links.update(urls)
                except:
                    pass
        else:
            # Single part message
            try:
                payload = msg.get_content()
                urls = extract_urls_from_text(payload)
                links.update(urls)
            except:
                pass
        
        # Also check headers for URLs (sometimes in List-Unsubscribe, etc.)
        for header_value in msg.values():
            if isinstance(header_value, str):
                urls = extract_urls_from_text(header_value)
                links.update(urls)
        
    except Exception as e:
        print(f"Error processing {eml_path}: {str(e)}")
    
    # Decode all URLs
    decoded_links = {decode_url(link) for link in links}
    
    return decoded_links

def main():
    """Main function to process all .eml files in the current directory."""
    current_dir = Path.cwd()
    eml_files = list(current_dir.glob('*.eml'))
    
    if not eml_files:
        print("No .eml files found in the current directory.")
        return
    
    print(f"Found {len(eml_files)} .eml file(s)\n")
    
    all_links = {}
    
    for eml_file in eml_files:
        print(f"Processing: {eml_file.name}")
        links = extract_links_from_eml(eml_file)
        
        if links:
            all_links[eml_file.name] = sorted(links)
            print(f"  Found {len(links)} link(s)")
        else:
            print(f"  No links found")
    
    # Output results
    print("\n" + "="*80)
    print("EXTRACTED LINKS")
    print("="*80 + "\n")
    
    for filename, links in all_links.items():
        print(f"\n{filename}:")
        print("-" * len(filename))
        for link in links:
            print(f"  {link}")
    
    # Optional: Save to file
    output_file = current_dir / "extracted_links.txt"
    with open(output_file, 'w', encoding='utf-8') as f:
        for filename, links in all_links.items():
            f.write(f"\n{filename}:\n")
            f.write("-" * len(filename) + "\n")
            for link in links:
                f.write(f"{link}\n")
    
    print(f"\n\nResults also saved to: {output_file}")

if __name__ == "__main__":
    main()