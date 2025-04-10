# Multi-stage build for frontend
# Stage 1: Build
FROM golang:1.20 AS builder
WORKDIR /app
# Copy go.mod first and download dependencies
COPY go.mod go.sum* ./
RUN go mod download
# Copy all source files
COPY . .
# Build the application with all source files
RUN go build -o frontend .

# Stage 2: Run
FROM ubuntu:22.04
WORKDIR /app
COPY --from=builder /app/frontend .
COPY --from=builder /app/templates ./templates
COPY --from=builder /app/static ./static
EXPOSE 8080
CMD ["./frontend"]
