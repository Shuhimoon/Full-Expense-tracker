FROM golang:1.24-bookworm AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/server ./cmd/server

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata \
    && printf 'hosts: files dns\n' > /etc/nsswitch.conf
ENV TZ=Asia/Taipei
COPY --from=build /out/server /server
COPY migrations /migrations
ENV MIGRATIONS_PATH=/migrations
EXPOSE 8080
ENTRYPOINT ["/server"]
