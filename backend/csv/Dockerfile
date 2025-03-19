FROM golang:1.23

ARG dbUser
ARG dbPassword
ARG dbName
ARG ipAddress
ARG port

# Copy the current directory (where the Dockerfile is) into /app in the container
WORKDIR /app
COPY . .

# Use a shell to substitute the environment variable in the command
CMD ["sh", "-c", "go run -ldflags \"-X main.dbUser=$dbUser -X main.dbPassword=$dbPassword -X main.dbName=$dbName -X main.ipAddress=$ipAddress -X main.port=$port\" main.go"]

# Expose the application port
EXPOSE 8081