FROM alpine:latest

RUN apk add --no-cache openssl

WORKDIR /app
COPY ca.sh /app/ca.sh
RUN chmod +x /app/ca.sh

ENTRYPOINT ["/app/ca.sh"]
CMD ["help"]
