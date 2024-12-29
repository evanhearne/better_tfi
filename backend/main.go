package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
)

func main() {
	// obtain api key from file x-api-key.txt
	apiKey, err := os.ReadFile("x-api-key.txt")
	if err != nil {
		fmt.Println("Error reading API key:", err)
		return
	}
	apiKeyStr := string(apiKey)
	// 
	println(string(gtfsr(apiKeyStr)))
}

func gtfsr(apiKey string) []byte {
	rootURL := "https://api.nationaltransport.ie/gtfsr/v2/"
	route := "gtfsr"
	url := rootURL + route
	client := &http.Client{}

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		fmt.Println(err)
		return nil
	}

	req.Header.Set("Cache-Control", "no-cache")
	req.Header.Set("x-api-key", apiKey)

	resp, err := client.Do(req)
	if err != nil {
		fmt.Println(err)
		return nil
	}
	defer resp.Body.Close()

	fmt.Println(resp.StatusCode)

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		fmt.Println(err)
		return nil
	}

	return body
}