---
name: socat
description: Create TCP/UDP tunnels, port forwards, serial bridges, and bidirectional byte streams. Use when proxying ports, exposing local services remotely, piping between devices/servers, or debugging network connections. Keywords: tunnel, port-forward, reverse-proxy, socket, TCP, UDP, bridge.
---

# Socat Skill

## Quick Reference

```bash
socat -V   # check version and capabilities built in
```

### Basic Syntax

```bash
socat [options] <ADDRESS1> <ADDRESS2>
```

Common address types: `TCP`, `UDP`, `LISTEN`, `EXEC`, `SYSTEM`, `PTY`, `PIPE`, `FILE`, `OPEN`, `SOCKS`.

### TCP Tunneling & Port Forwarding

```bash
# Forward local port 8080 -> remote host:443 (outbound proxy)
socat TCP-LISTEN:8080,reuseaddr,fork TCP:target.example.com:443

# Expose a local service to the outside via reverse tunnel
socat TCP-LISTEN:9090,reuseaddr,fork SOCKS://proxy-host:22,socksport=1080

# TCP to localhost port relay (mirrored traffic)
socat TCP-LISTEN:6379,reuseaddr,fork TCP:redis-internal.local:6379
```

### Unix/SSL Endpoints

```bash
# Listen on a Unix domain socket, forward to TCP
socat UNIX-LISTEN:/tmp/myapp.sock,reuseaddr,fork TCP:localhost:8080

# TLS-terminated listener -> plain HTTP upstream
socat OPENSSL-LISTEN:443,cert=/path/to/cert.pem,key=/path/to/key.pem,reuseaddr,fork TCP:backend:8080

# Client with mTLS
socat STDIO OPENSSL:host:port,cert=client.crt,key=client.key,cafile=ca.crt
```

### Serial / IoT Bridges

```bash
# UART to terminal (nohup for background)
socat -x -v PTY=/dev/pts/ttyV0,link=/tmp/virtual-uart,raw,echo=0 EXEC:"cat",b115200,crnl

# Real serial port bridge: /dev/ttyS0 -> TCP client
socat -x -v /dev/ttyUSB0,rawer,b115200 TCP-LISTEN:9600,reuseaddr
```

### Pipe & Process Chains

```bash
# Background forward (detached) with process tracking
nohup socat TCP-LISTEN:3000,reuseaddr,fork TCP:10.0.1.50:80 &> /var/log/socat-tunnel.log &
PID=$(pgrep -f "socat.*TCP-LISTEN:3000")
kill $PID  # stop the tunnel

# Run a one-shot command through socat (e.g., healthcheck)
socat -t5 TCP:host:port STDIO
```

## Common Flags

| Flag | Meaning |
|---|---|
| `reuseaddr` | Rebind port immediately after close |
| `fork` | Spawn new process per client connection (for servers) |
| `-x` or `-v` | Hex dump traffic to stderr for debugging |
| `linger=1` | Wait for outstanding data on shutdown |

## Workflow Tips

- Use `fork` for multi-client listeners; omit it if only one concurrent connection is expected.
- Log output (`-x -v`) helps debug encoding or framing issues with serial and raw TCP flows.
- In Dockerized environments, map the socat listener port to host: `-p <host-port>:<container-listen-port>`.
