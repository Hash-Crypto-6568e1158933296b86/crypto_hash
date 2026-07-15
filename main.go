package main

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"log"
	"math/big"
	"os"
	"strings"

	"github.com/btcsuite/btcd/btcec/v2"
	"github.com/btcsuite/btcd/btcutil"
	"github.com/btcsuite/btcd/chaincfg"
	"golang.org/x/crypto/ripemd160"
)

// GerarPorcentagemAleatoria gera um decimal aleatório entre 0 e 1 com 39 dígitos
func GerarPorcentagemAleatoria() *big.Float {
	// Gera 39 dígitos aleatórios
	digitos := make([]byte, 39)
	for i := range digitos {
		digitos[i] = byte('0' + randInt(0, 9))
	}

	str := "0." + string(digitos)
	result := new(big.Float)
	result.SetString(str)
	return result
}

// randInt gera um número inteiro aleatório entre min e max (inclusive)
func randInt(min, max int) int {
	return min + int(randInt64(int64(max-min+1)))
}

func randInt64(n int64) int64 {
	if n <= 0 {
		return 0
	}

	max := big.NewInt(n)
	result, err := rand.Int(rand.Reader, max)
	if err != nil {
		return 0
	}
	return result.Int64()
}

// PrivateToAddress converte uma chave privada inteira para endereço Bitcoin
func PrivateToAddress(privateKeyInt *big.Int) (string, string, error) {
	// Converte para bytes (32 bytes)
	privateKeyBytes := privateKeyInt.Bytes()

	// Preenche com zeros à esquerda se necessário
	if len(privateKeyBytes) < 32 {
		padded := make([]byte, 32)
		copy(padded[32-len(privateKeyBytes):], privateKeyBytes)
		privateKeyBytes = padded
	}

	// Deriva a chave privada
	privKey, _ := btcec.PrivKeyFromBytes(privateKeyBytes)

	// Serializa a chave pública comprimida
	compressedPubKey := privKey.PubKey().SerializeCompressed()

	// Calcula SHA256
	sha256Hash := sha256.Sum256(compressedPubKey)

	// Calcula RIPEMD160
	ripemd160Hasher := ripemd160.New()
	ripemd160Hasher.Write(sha256Hash[:])
	ripemd160Hash := ripemd160Hasher.Sum(nil)

	// Cria endereço Bitcoin
	addr, err := btcutil.NewAddressPubKeyHash(ripemd160Hash, &chaincfg.MainNetParams)
	if err != nil {
		return "", "", err
	}

	return addr.EncodeAddress(), hex.EncodeToString(privateKeyBytes), nil
}

// EscolherPorcentagem seleciona um valor aleatório dentro do intervalo baseado em porcentagem
func EscolherPorcentagem(minHex, maxHex string) (*big.Int, *big.Int, string) {
	minInt := new(big.Int)
	maxInt := new(big.Int)

	minInt.SetString(minHex[2:], 16) // Remove "0x"
	maxInt.SetString(maxHex[2:], 16) // Remove "0x"

	porcentagem := GerarPorcentagemAleatoria()
	fmt.Printf("Porcentagem gerada: \033[93m%s\033[0m\n", porcentagem.String())

	// Calcula o intervalo
	intervalo := new(big.Int).Sub(maxInt, minInt)

	// Converte intervalo para big.Float para multiplicação
	intervaloFloat := new(big.Float).SetInt(intervalo)

	// Calcula valor_escolhido = min_int + (intervalo * porcentagem)
	produto := new(big.Float).Mul(intervaloFloat, porcentagem)

	// Converte produto para big.Int
	produtoInt := new(big.Int)
	produto.Int(produtoInt)

	valorEscolhido := new(big.Int).Add(minInt, produtoInt)

	hexResultado := "0x" + valorEscolhido.Text(16)
	fmt.Printf("Iniciando busca em: \033[92m%s\033[0m\n", hexResultado)

	// Deriva endereço a partir da chave privada
	endereco, chaveHex, err := PrivateToAddress(valorEscolhido)
	if err != nil {
		log.Fatal("Erro ao gerar endereço:", err)
	}

	fmt.Printf("\n🔑 Chave privada: \033[95m%s\033[0m\n", chaveHex)
	fmt.Printf("🏦 Endereço correspondente: \033[94m%s\033[0m\n", endereco)

	enderecoBtc := "1PWo3JeB9jrGwfHDNpdGK54CRas7fsVzXU"
	fmt.Printf("🎯 Endereço Bitcoin Puzzle 71: \033[96m%s\033[0m\n", enderecoBtc)

	// Salva no arquivo
	SalvarResultado(porcentagem.String(), hexResultado, chaveHex, endereco, enderecoBtc)

	return valorEscolhido, maxInt, hexResultado
}

// SalvarResultado salva os resultados no arquivo
func SalvarResultado(porcentagem, hexKey, privateKey, address, puzzleAddress string) {
	file, err := os.OpenFile("result_71.txt", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatal("Erro ao abrir arquivo:", err)
	}
	defer file.Close()

	content := fmt.Sprintf("Porcentagem: %s\n", porcentagem)
	content += fmt.Sprintf("Início da busca: %s\n", hexKey)
	content += fmt.Sprintf("Chave privada: %s\n", privateKey)
	content += fmt.Sprintf("Endereço gerado: %s\n", address)
	content += fmt.Sprintf("Endereço Puzzle 71: %s\n", puzzleAddress)
	content += strings.Repeat("-", 40) + "\n"

	if _, err := file.WriteString(content); err != nil {
		log.Fatal("Erro ao escrever no arquivo:", err)
	}
}

func main() {
	minValor := "0x400000000000000000"
	maxValor := "0x7fffffffffffffffff"

	start, end, hexKey := EscolherPorcentagem(minValor, maxValor)
	fmt.Printf("\n📊 Intervalo: \033[95m0x%s : 0x%s\033[0m\n", start.Text(16), end.Text(16))
	fmt.Printf("Chave hexadecimal: %s\n", hexKey)
}
