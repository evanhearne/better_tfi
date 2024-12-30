package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

var (
	cache          []byte
	cacheTimestamp time.Time
	cacheMutex     sync.Mutex
)

func main() {
	// Obtain API key from file
	apiKey, err := os.ReadFile("x-api-key.txt")
	if err != nil {
		fmt.Println("Error reading API key:", err)
		return
	}
	apiKeyStr := strings.TrimSpace(string(apiKey))

	// Start HTTP server
	http.HandleFunc("/gtfsr", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		response, err := getCachedGtfsrData(apiKeyStr)
		if err != nil {
			http.Error(w, "Error fetching GTFSR data: "+err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.Write(response)
	})

	fmt.Println("Server running on port 8080")
	http.ListenAndServe(":8080", nil)
}

func getCachedGtfsrData(apiKey string) ([]byte, error) {
	cacheMutex.Lock()
	defer cacheMutex.Unlock()

	// Check if cache is valid (20 seconds TTL)
	if time.Since(cacheTimestamp) < 20*time.Second && cache != nil {
		return cache, nil
	}

	// Fetch new data
	response, err := fetchGtfsrData(apiKey)
	if err != nil {
		return nil, err
	}

	// Update cache
	cache = response
	cacheTimestamp = time.Now()

	return response, nil
}

func fetchGtfsrData(apiKey string) ([]byte, error) {
	rootURL := "https://api.nationaltransport.ie/gtfsr/v2/"
	route := "gtfsr"
	url := rootURL + route
	client := &http.Client{}

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("error creating request: %w", err)
	}

	req.Header.Set("Cache-Control", "no-cache")
	req.Header.Set("x-api-key", apiKey)

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("error making HTTP request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("received non-200 response: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("error reading response body: %w", err)
	}

	return body, nil
}
