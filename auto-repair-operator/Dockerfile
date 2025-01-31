FROM golang:1.23.5 as builder

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY . ./

RUN CGO_ENABLED=0 GOOS=linux go build -o operator . && ls -l /app

FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /app

COPY --from=builder /app/operator .
COPY --from=builder /app/kubeconfig .

RUN ls -l /app && chmod +x /app/operator

RUN export KUBECONFIG=$(pwd)/kubeconfig

ENTRYPOINT ["./operator"]
