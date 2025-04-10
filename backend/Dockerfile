# Multi-stage build for backend
# Stage 1: Build
FROM golang:1.20 AS builder
WORKDIR /app
# Copy go.mod first and download dependencies
COPY go.mod go.sum ./
RUN go mod download
# Copy all source files
COPY . .
# Build the application with all source files
RUN CGO_ENABLED=0 go build -o backend .

# Stage 2: Run
FROM debian:bullseye-slim
WORKDIR /app
COPY --from=builder /app/backend .
EXPOSE 9000
CMD ["./backend"]