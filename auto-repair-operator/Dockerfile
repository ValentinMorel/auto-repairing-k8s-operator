FROM golang:1.22-buster

WORKDIR /app

COPY . .

RUN go mod download

RUN go build -o operator .

FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /app 

COPY --from=builder /app/operator .

ENTRYPOINT ["./operator"]
