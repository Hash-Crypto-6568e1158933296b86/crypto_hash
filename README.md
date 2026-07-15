# 🧠 Crypto_Hash – Windows e Linux

Ferramenta para busca de chaves e endereços Bitcoin por força bruta utilizando modos **address** e **BSGS**.

---

📦 Windows – Exemplos de uso

```
crypto_hash -h
```

```
crypto_hash -m address -f tests/71.txt -t 24 -l compress -6 -S -e -r 400000000000000000:7fffffffffffffffff -n 4096
```

```
crypto_hash -m rmd160 -f tests/71.rmd -t 24 -l compress -6 -S -e -r 400000000000000000:7fffffffffffffffff -n 4096
```

```
crypto_hash -m bsgs -t 24 -f tests/135.txt -k 4096 -6 -S -e -r 4000000000000000000000000000000000:7fffffffffffffffffffffffffffffffff
```

🐧 Linux – Exemplos de uso

```
./crypto_hash -h
```

```
./crypto_hash -m address -f tests/71.txt -t 24 -l compress -6 -S -e -r 400000000000000000:7fffffffffffffffff -n 4096
```

```
./crypto_hash -m rmd160 -f tests/71.rmd -t 24 -l compress -6 -S -e -r 400000000000000000:7fffffffffffffffff -n 4096
```

```
./crypto_hash -m bsgs -t 24 -f tests/135.txt -k 4096 -6 -S -e -r 4000000000000000000000000000000000:7fffffffffffffffffffffffffffffffff
```

---

## 🧠 Parâmetros recomendados para o modo BSGS de acordo com sua RAM

| RAM    | Parâmetros recomendados        |
| ------ | ------------------------------- |
| 2 GB   | `-k 128`                        |
| 4 GB   | `-k 256`                        |
| 8 GB   | `-k 512`                        |
| 16 GB  | `-k 1024`                       |
| 32 GB  | `-k 2048`                       |
| 64 GB  | `-n 0x100000000000 -k 4096`     |
| 128 GB | `-n 0x400000000000 -k 4096`     |
| 256 GB | `-n 0x400000000000 -k 8192`     |
| 512 GB | `-n 0x1000000000000 -k 8192`    |
| 1 TB   | `-n 0x1000000000000 -k 16384`   |
| 2 TB   | `-n 0x4000000000000 -k 16384`   |
| 4 TB   | `-n 0x4000000000000 -k 32768`   |
| 8 TB   | `-n 0x10000000000000 -k 32768`  |

---

## 🛠️ Instruções para compilar o crypto_hash (Linux)

```bash
apt update && apt upgrade
apt install git -y
apt install build-essential -y
apt install libssl-dev -y
apt install libgmp-dev -y
git clone https://github.com/Hash-Crypto-6568e1158933296b86/crypto_hash.git
cd crypto_hash
make
```

### Versão Legacy

```bash
make legacy
```

## 🪟 Instruções para compilar no Windows (via Cygwin)

Para compilar para Windows, use o [Cygwin](https://www.cygwin.com/).

```bash
git clone https://github.com/Hash-Crypto-6568e1158933296b86/crypto_hash.git
cd crypto_hash
make
```

---

## 🤖 crypto_hash_BOT (`71.sh`)

Esse bot captura as chaves testadas a cada 5 minutos e salva no arquivo 💾 `progresso_71.json`.

O programa pode ser interrompido com `Ctrl+C` — a chave é salva automaticamente e, ao executar o bot novamente, ele retoma a partir da mesma chave. Isso também se aplica a quedas de energia: o programa retoma da última chave que estava sendo testada no momento da interrupção.

Todo o programa roda **offline**, incluindo o bot — não há conexão com a internet.

Esse bot funciona em conjunto com o `main.go`, que gera uma chave hex do puzzle 71 e a testa pelo tempo escolhido (por exemplo, opção **4 – 4 horas**). A cada intervalo configurado, ele gera uma nova chave e a testa; se encontrar o resultado, imprime na tela e salva no arquivo `KEYFOUNDKEYFOUND.txt`.

### Executando o bot

```bash
chmod +x 71.sh
./71.sh
```

<img width="705" height="887" alt="71 sh" src="https://github.com/user-attachments/assets/5b19adb6-af29-449f-af7c-e15366c1462c" />

---

## 📚 Código original

[https://github.com/albertobsd/keyhunt](https://github.com/albertobsd/keyhunt)
