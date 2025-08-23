# Use Rust 1.82 or newer to fix zerovec build
FROM rust:1.84.0 as builder

WORKDIR /app
COPY . .

RUN cargo build --release

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y ca-certificates curl && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/rustProxy /usr/local/bin/rustProxy

EXPOSE 8082

CMD ["rustProxy"]
