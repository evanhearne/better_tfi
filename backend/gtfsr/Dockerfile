FROM golang:1.23

# Set the environment variable
ARG apiKey

# Copy the current directory (where the Dockerfile is) into /app in the container
WORKDIR /app
COPY . .

# Use a shell to substitute the environment variable in the command
CMD ["sh", "-c", "go run -ldflags \"-X main.apiKey=$apikey\" main.go"]

# Expose the application port
EXPOSE 8080