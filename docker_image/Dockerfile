FROM golang:1.23.9-alpine AS builder

RUN apk update && apk add --no-cache make bash nodejs npm git

ARG explorer_base_path
ARG wallet_base_path

WORKDIR /go/src/github.com/canopy-network/canopy

# Clone the eth-oracle branch
RUN git clone -b eth-oracle https://github.com/canopy-network/canopy.git .

ENV EXPLORER_BASE_PATH=${EXPLORER_BASE_PATH}
ENV WALLET_BASE_PATH=${WALLET_BASE_PATH}

RUN make build/wallet
RUN make build/explorer
RUN go build -a -o bin ./cmd/main/...

FROM alpine:3.19
WORKDIR /app
COPY --from=builder /go/src/github.com/canopy-network/canopy/bin ./
ENTRYPOINT ["/app/bin"]
