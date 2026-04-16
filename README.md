
 # 🧠 Crypto_Hash – Windows e Linux

Ferramenta para busca de chaves e endereços Bitcoin por força bruta utilizando modos **address** e **BSGS**.

---

## 📦 Windows/🐧 Linux – Exemplos de uso

```bash
crypto_hash -h

crypto_hash -m address -f tests/71.txt -t 24 -l compress -6 -S -e -r 400000000000000000:7fffffffffffffffff -n 4096

crypto_hash -m rmd160 -f tests/71.rmd -t 24 -l compress -6 -S -e -r 400000000000000000:7fffffffffffffffff -n 4096

crypto_hash -m bsgs -t 24 -f tests/135.txt -k 4096 -6 -S -e 4000000000000000000000000000000000:7fffffffffffffffffffffffffffffffff

🐧 Linux – Exemplos de uso

./crypto_hash -h

./crypto_hash -m address -f tests/71.txt -t 24 -l compress -6 -S -e -r 400000000000000000:7fffffffffffffffff -n 4096

./crypto_hash -m rmd160 -f tests/71.rmd -t 24 -l compress -6 -S -e -r 400000000000000000:7fffffffffffffffff -n 4096

./crypto_hash -m bsgs -t 24 -f tests/135.txt -k 4096 -6 -S -e 4000000000000000000000000000000000:7fffffffffffffffffffffffffffffffff

🧠 Parâmetros recomendados para o modo BSGS de acordo com sua RAM

| RAM    | Parâmetros recomendados        |
| ------ | ------------------------------ |
| 2 GB   | `-k 128`                       |
| 4 GB   | `-k 256`                       |
| 8 GB   | `-k 512`                       |
| 16 GB  | `-k 1024`                      |
| 32 GB  | `-k 2048`                      |
| 64 GB  | `-n 0x100000000000 -k 4096`    |
| 128 GB | `-n 0x400000000000 -k 4096`    |
| 256 GB | `-n 0x400000000000 -k 8192`    |
| 512 GB | `-n 0x1000000000000 -k 8192`   |
| 1 TB   | `-n 0x1000000000000 -k 16384`  |
| 2 TB   | `-n 0x4000000000000 -k 16384`  |
| 4 TB   | `-n 0x4000000000000 -k 32768`  |
| 8 TB   | `-n 0x10000000000000 -k 32768` |

instruções para compilar o fox_crypto

apt update && apt upgrade
apt install git -y
apt install build-essential -y
apt install libssl-dev -y
apt install libgmp-dev -y

git https://github.com/Hash-Crypto-6568e1158933296b86/crypto_hash.git

cd crypto_hash

make

make legacy

Para compilar para windows use o Cygwin.

git https://github.com/Hash-Crypto-6568e1158933296b86/crypto_hash.git

cd crypto_hash

make


