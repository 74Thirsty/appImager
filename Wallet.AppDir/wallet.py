#!/usr/bin/env python3
import os
import json
import getpass
import secrets
import sys
from pathlib import Path
from eth_account import Account
from mnemonic import Mnemonic
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from web3 import Web3

# === CONFIG ===
DATA_FILE = Path("wallets.enc")
ETH_RPC = "https://ethereum.publicnode.com"
w3 = Web3(Web3.HTTPProvider(ETH_RPC))
Account.enable_unaudited_hdwallet_features()


# === Encryption Utils ===
def encrypt_data(password: str, data: dict) -> bytes:
    salt = secrets.token_bytes(16)
    key = AESGCM.generate_key(bit_length=256)
    aesgcm = AESGCM(derive_key(password, salt))
    nonce = secrets.token_bytes(12)
    ct = aesgcm.encrypt(nonce, json.dumps(data).encode(), None)
    return salt + nonce + ct


def decrypt_data(password: str, blob: bytes) -> dict:
    salt, nonce, ct = blob[:16], blob[16:28], blob[28:]
    aesgcm = AESGCM(derive_key(password, salt))
    data = aesgcm.decrypt(nonce, ct, None)
    return json.loads(data.decode())


def derive_key(password: str, salt: bytes) -> bytes:
    from hashlib import pbkdf2_hmac
    return pbkdf2_hmac("sha256", password.encode(), salt, 200000, dklen=32)


# === Wallet File Management ===
def load_wallets(password: str) -> dict:
    if not DATA_FILE.exists():
        return {}
    with open(DATA_FILE, "rb") as f:
        blob = f.read()
    try:
        return decrypt_data(password, blob)
    except Exception:
        print("❌ Incorrect password or corrupted file.")
        return {}


def save_wallets(password: str, wallets: dict):
    blob = encrypt_data(password, wallets)
    with open(DATA_FILE, "wb") as f:
        f.write(blob)


# === Wallet Actions ===
def create_wallet(wallets: dict):
    acct, mnemonic = generate_wallet()
    wallets[acct.address] = {
        "private_key": acct.key.hex(),
        "mnemonic": mnemonic
    }
    print(f"✅ Created wallet {acct.address}")
    return wallets


def generate_wallet():
    mnemo = Mnemonic("english")
    mnemonic = mnemo.generate(strength=128)
    acct = Account.from_mnemonic(mnemonic)
    return acct, mnemonic


def list_wallets(wallets: dict):
    if not wallets:
        print("⚠️ No wallets stored.")
        return
    for i, addr in enumerate(wallets.keys(), 1):
        print(f"{i}. {addr}")


def delete_wallet(wallets: dict):
    addr = input("Enter address to delete: ").strip()
    if addr in wallets:
        del wallets[addr]
        print("🗑 Deleted.")
    else:
        print("❌ Address not found.")
    return wallets


def import_wallet(wallets: dict):
    choice = input("Import from (1) Private Key or (2) Mnemonic? ")
    if choice == "1":
        pk = input("Private key (0x...): ").strip()
        acct = Account.from_key(pk)
        wallets[acct.address] = {
            "private_key": pk,
            "mnemonic": None
        }
        print(f"✅ Imported {acct.address}")
    elif choice == "2":
        mnemonic = input("Mnemonic: ").strip()
        acct = Account.from_mnemonic(mnemonic)
        wallets[acct.address] = {
            "private_key": acct.key.hex(),
            "mnemonic": mnemonic
        }
        print(f"✅ Imported {acct.address}")
    return wallets


def export_wallet(wallets: dict):
    addr = input("Address to export: ").strip()
    if addr not in wallets:
        print("❌ Address not found.")
        return
    fname = addr.replace("0x", "") + ".json"
    with open(fname, "w") as f:
        json.dump(wallets[addr], f, indent=2)
    print(f"📤 Exported to {fname}")


def check_balance(wallets: dict):
    addr = input("Address to check balance: ").strip()
    if addr not in wallets:
        print("❌ Address not found.")
        return
    balance = w3.eth.get_balance(addr)
    eth_balance = w3.from_wei(balance, "ether")
    print(f"💰 {addr} Balance: {eth_balance} ETH")


def backup_all(wallets: dict):
    fname = "wallets_backup.json"
    with open(fname, "w") as f:
        json.dump(wallets, f, indent=2)
    print(f"📦 Backup saved to {fname}")


def restore_backup(wallets: dict):
    fname = input("Backup file path: ").strip()
    if not os.path.isfile(fname):
        print("❌ File not found or is a directory.")
        return wallets
    try:
        with open(fname, "r") as f:
            data = json.load(f)
        wallets.update(data)
        print("♻️ Backup restored.")
    except Exception as e:
        print(f"❌ Failed to restore backup: {e}")
    return wallets


# === Main Menu ===
def main():
    print("=== Python Wallet Manager ===")
    password = getpass.getpass("Master password: ")
    wallets = load_wallets(password)

    while True:
        print("\nMenu:")
        print("1. Create Wallet")
        print("2. List Wallets")
        print("3. Import Wallet")
        print("4. Export Wallet")
        print("5. Delete Wallet")
        print("6. Check Balance")
        print("7. Backup All")
        print("8. Restore From Backup")
        print("0. Exit")

        choice = input("> ").strip()
        if choice == "1":
            wallets = create_wallet(wallets)
        elif choice == "2":
            list_wallets(wallets)
        elif choice == "3":
            wallets = import_wallet(wallets)
        elif choice == "4":
            export_wallet(wallets)
        elif choice == "5":
            wallets = delete_wallet(wallets)
        elif choice == "6":
            check_balance(wallets)
        elif choice == "7":
            backup_all(wallets)
        elif choice == "8":
            wallets = restore_backup(wallets)
        elif choice == "0":
            save_wallets(password, wallets)
            print("💾 Changes saved. Goodbye.")
            sys.exit()
        else:
            print("❌ Invalid choice.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n⚠️ Interrupted.")

