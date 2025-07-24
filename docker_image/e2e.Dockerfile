FROM golang:1.23.9-alpine as builder

RUN apk update && apk add --no-cache make bash nodejs npm git

ARG explorer_base_path
ARG wallet_base_path

env explorer_base_path=${explorer_base_path}
env wallet_base_path=${wallet_base_path}

# Clone directly to the desired location
RUN git clone -b eth-oracle https://github.com/canopy-network/canopy.git /go/src/github.com/canopy-network/canopy

workdir /go/src/github.com/canopy-network/canopy
run make build/wallet
run make build/explorer

WORKDIR /go/src/github.com/canopy-network/canopy/cmd/rpc/oracle/testing
RUN go build .

FROM alpine:3.19
WORKDIR /app
COPY --from=builder /go/src/github.com/canopy-network/canopy/cmd/rpc/oracle/testing/testing ./bin
ENTRYPOINT ["/app/bin"]
