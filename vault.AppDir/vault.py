#!/usr/bin/env python3
import os
import sys
import json
import getpass
import shutil
import base64
from pathlib import Path
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes
from cryptography.fernet import Fernet, InvalidToken

VAULT_FILE = Path("vault.enc")
SALT_FILE = Path("vault.salt")

# === Encryption Helpers ===
def derive_key(password: str, salt: bytes) -> bytes:
    """Derive AES key from password + salt."""
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=390000,
        backend=default_backend()
    )
    return base64.urlsafe_b64encode(kdf.derive(password.encode()))

def create_vault(password: str):
    """Initialize new vault."""
    salt = os.urandom(16)
    SALT_FILE.write_bytes(salt)
    key = derive_key(password, salt)
    data = {}
    token = Fernet(key).encrypt(json.dumps(data).encode())
    VAULT_FILE.write_bytes(token)
    print("✅ New vault created.")

def load_vault(password: str) -> dict:
    """Decrypt and load vault data."""
    salt = SALT_FILE.read_bytes()
    key = derive_key(password, salt)
    f = Fernet(key)
    token = VAULT_FILE.read_bytes()
    decrypted = f.decrypt(token)  # Raises InvalidToken if wrong password
    return json.loads(decrypted.decode()), key

def save_vault(data: dict, key: bytes):
    """Encrypt and save vault data."""
    token = Fernet(key).encrypt(json.dumps(data).encode())
    VAULT_FILE.write_bytes(token)

# === Transport Placeholder ===
def sync_to_remote():
    """Future: sync vault to SMB/FTP/WebDAV/Cloud."""
    pass

# === Interactive Menu ===
def add_entry(data: dict):
    label = input("Label for address (e.g. Contract1, WalletA): ").strip()
    addr = input("Address: ").strip()
    data[label] = addr
    print(f"✅ Added {label}.")

def list_entries(data: dict):
    if not data:
        print("📭 Vault is empty.")
        return
    print("\nStored addresses:")
    for label, addr in data.items():
        print(f" - {label}: {addr}")

def delete_entry(data: dict):
    label = input("Label to delete: ").strip()
    if label in data:
        del data[label]
        print(f"🗑 Deleted {label}.")
    else:
        print("❌ Not found.")

# === Main Execution ===
def main():
    # Handle reset flag
    if "--reset" in sys.argv:
        if VAULT_FILE.exists():
            shutil.move(VAULT_FILE, f"{VAULT_FILE}.bak")
        if SALT_FILE.exists():
            shutil.move(SALT_FILE, f"{SALT_FILE}.bak")
        print("🧨 Vault reset. Starting fresh...")
    
    if not VAULT_FILE.exists():
        # First run: set master password
        pwd = getpass.getpass("Set master password: ")
        create_vault(pwd)

    # Always ask for password (max 3 tries)
    for attempt in range(3):
        pwd = getpass.getpass("Enter master password: ")
        try:
            data, key = load_vault(pwd)
            break
        except InvalidToken:
            print("❌ Wrong password.")
            if attempt == 2:
                print("🚪 Too many failed attempts. Exiting.")
                sys.exit(1)
    else:
        sys.exit(1)

    # Main menu loop
    while True:
        print("\n--- Vault Menu ---")
        print("1. Add entry")
        print("2. List entries")
        print("3. Delete entry")
        print("4. Save & Exit")
        choice = input("Select: ").strip()

        if choice == "1":
            add_entry(data)
        elif choice == "2":
            list_entries(data)
        elif choice == "3":
            delete_entry(data)
        elif choice == "4":
            save_vault(data, key)
            print("💾 Vault saved. Goodbye.")
            sync_to_remote()
            break
        else:
            print("❌ Invalid choice.")

if __name__ == "__main__":
    main()
