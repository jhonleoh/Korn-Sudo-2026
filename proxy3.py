#!/usr/bin/env python3
"""
Project Fog Modernized - HTTP Tunneling Proxy (Python 3)
Supports HTTP CONNECT method for SSL/TLS tunneling.
Compatible with Python 3.6+ (all Debian 9+ and Ubuntu 18+).

Usage:
    python3 proxy3.py [PORT] [STATUS_MESSAGE]
    python3 proxy3.py 8880 ProjectFog

Features:
    - HTTP CONNECT tunnel (for HTTPS/SSL proxying)
    - Direct HTTP forwarding
    - Connection logging
    - Graceful shutdown (SIGINT/SIGTERM)
    - Configurable via command line
"""

import socket
import threading
import select
import sys
import signal
import logging
import time
import os

# ─── Configuration ───────────────────────────────────────────────
LISTEN_IP = '0.0.0.0'
BUFFER_SIZE = 65536
BACKLOG = 256
SELECT_TIMEOUT = 5.0
CONNECT_TIMEOUT = 10
DEFAULT_PORT = 8880
DEFAULT_MSG = 'ProjectFog'

# ─── Logging Setup ───────────────────────────────────────────────
log_dir = '/var/log/project-fog'
os.makedirs(log_dir, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(os.path.join(log_dir, 'proxy.log'), mode='a'),
    ]
)
logger = logging.getLogger('FogProxy')


# ─── Connection Handler ─────────────────────────────────────────
class ConnectionHandler(threading.Thread):
    """Handles individual client connections with HTTP CONNECT tunneling."""

    def __init__(self, client_sock, address, status_msg):
        super().__init__(daemon=True)
        self.client = client_sock
        self.address = address
        self.status_msg = status_msg

    def run(self):
        try:
            self.client.settimeout(CONNECT_TIMEOUT)
            data = self.client.recv(BUFFER_SIZE)
            if not data:
                self.client.close()
                return

            request = data.decode('utf-8', errors='replace')
            first_line = request.split('\n')[0].strip()
            logger.info(f"[{self.address[0]}:{self.address[1]}] {first_line}")

            if request.upper().startswith('CONNECT'):
                self._handle_connect(request)
            else:
                self._handle_direct(data, request)

        except socket.timeout:
            logger.debug(f"[{self.address[0]}] Connection timed out")
        except ConnectionResetError:
            logger.debug(f"[{self.address[0]}] Connection reset by peer")
        except BrokenPipeError:
            logger.debug(f"[{self.address[0]}] Broken pipe")
        except Exception as e:
            logger.error(f"[{self.address[0]}] Error: {e}")
        finally:
            try:
                self.client.close()
            except Exception:
                pass

    def _handle_connect(self, request):
        """Handle HTTP CONNECT method for SSL/TLS tunneling."""
        try:
            # Parse CONNECT host:port
            first_line = request.split('\n')[0]
            target = first_line.split()[1]

            if ':' in target:
                host, port = target.rsplit(':', 1)
                port = int(port)
            else:
                host = target
                port = 443

            # Connect to the target server
            remote = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote.settimeout(CONNECT_TIMEOUT)
            remote.connect((host, port))

            # Send 200 Connection Established
            response = f"HTTP/1.1 200 {self.status_msg}\r\n\r\n"
            self.client.sendall(response.encode())

            # Tunnel data between client and remote
            self._tunnel(self.client, remote)

        except socket.timeout:
            self._send_error(504, "Gateway Timeout")
        except ConnectionRefusedError:
            self._send_error(502, "Bad Gateway - Connection Refused")
        except socket.gaierror:
            self._send_error(502, "Bad Gateway - DNS Resolution Failed")
        except Exception as e:
            logger.error(f"CONNECT error: {e}")
            self._send_error(502, "Bad Gateway")

    def _handle_direct(self, raw_data, request):
        """Handle direct HTTP requests (non-CONNECT)."""
        try:
            # Parse the target from the request
            first_line = request.split('\n')[0]
            parts = first_line.split()

            if len(parts) < 2:
                self._send_error(400, "Bad Request")
                return

            url = parts[1]

            # Extract host and port from URL
            if url.startswith('http://'):
                url_part = url[7:]
            elif url.startswith('https://'):
                url_part = url[8:]
            else:
                # Might be a direct path request - send 200 OK
                response = f"HTTP/1.1 200 {self.status_msg}\r\n"
                response += "Content-Type: text/plain\r\n"
                response += f"Content-Length: {len(self.status_msg)}\r\n"
                response += "\r\n"
                response += self.status_msg
                self.client.sendall(response.encode())
                return

            if '/' in url_part:
                host_port = url_part.split('/')[0]
            else:
                host_port = url_part

            if ':' in host_port:
                host, port = host_port.rsplit(':', 1)
                port = int(port)
            else:
                host = host_port
                port = 80

            # Connect to remote
            remote = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote.settimeout(CONNECT_TIMEOUT)
            remote.connect((host, port))
            remote.sendall(raw_data)

            # Tunnel the response back
            self._tunnel(self.client, remote)

        except Exception as e:
            logger.error(f"Direct proxy error: {e}")
            self._send_error(502, "Bad Gateway")

    def _tunnel(self, client_sock, remote_sock):
        """Bidirectional data tunnel between client and remote."""
        client_sock.setblocking(False)
        remote_sock.setblocking(False)

        sockets = [client_sock, remote_sock]
        timeout_count = 0
        max_timeouts = 60  # 5 minutes with 5s timeout

        try:
            while True:
                readable, _, errors = select.select(sockets, [], sockets, SELECT_TIMEOUT)

                if errors:
                    break

                if not readable:
                    timeout_count += 1
                    if timeout_count >= max_timeouts:
                        break
                    continue

                timeout_count = 0

                for sock in readable:
                    try:
                        data = sock.recv(BUFFER_SIZE)
                        if not data:
                            return

                        if sock is client_sock:
                            remote_sock.sendall(data)
                        else:
                            client_sock.sendall(data)
                    except (ConnectionResetError, BrokenPipeError, OSError):
                        return
        finally:
            try:
                remote_sock.close()
            except Exception:
                pass

    def _send_error(self, code, message):
        """Send an HTTP error response to the client."""
        try:
            body = f"<html><body><h1>{code} {message}</h1></body></html>"
            response = f"HTTP/1.1 {code} {message}\r\n"
            response += "Content-Type: text/html\r\n"
            response += f"Content-Length: {len(body)}\r\n"
            response += "Connection: close\r\n"
            response += "\r\n"
            response += body
            self.client.sendall(response.encode())
        except Exception:
            pass


# ─── Server ──────────────────────────────────────────────────────
class ProxyServer:
    """Main proxy server with graceful shutdown support."""

    def __init__(self, host, port, status_msg):
        self.host = host
        self.port = port
        self.status_msg = status_msg
        self.running = False
        self.server_sock = None

    def start(self):
        """Start the proxy server."""
        self.server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

        # SO_REUSEPORT for newer kernels (optional)
        try:
            self.server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        except (AttributeError, OSError):
            pass

        self.server_sock.settimeout(1.0)
        self.server_sock.bind((self.host, self.port))
        self.server_sock.listen(BACKLOG)
        self.running = True

        logger.info(f"Project Fog Proxy started on {self.host}:{self.port}")
        logger.info(f"Status message: {self.status_msg}")

        while self.running:
            try:
                client_sock, address = self.server_sock.accept()
                handler = ConnectionHandler(client_sock, address, self.status_msg)
                handler.start()
            except socket.timeout:
                continue
            except OSError:
                if self.running:
                    logger.error("Server socket error")
                break

    def stop(self):
        """Gracefully stop the proxy server."""
        logger.info("Shutting down proxy server...")
        self.running = False
        if self.server_sock:
            try:
                self.server_sock.close()
            except Exception:
                pass


# ─── Main ────────────────────────────────────────────────────────
def main():
    # Parse command line arguments
    try:
        port = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PORT
    except ValueError:
        logger.error(f"Invalid port: {sys.argv[1]}")
        sys.exit(1)

    status_msg = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_MSG

    if port < 1 or port > 65535:
        logger.error(f"Port must be between 1 and 65535, got: {port}")
        sys.exit(1)

    server = ProxyServer(LISTEN_IP, port, status_msg)

    # Signal handlers for graceful shutdown
    def signal_handler(signum, frame):
        server.stop()
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    try:
        server.start()
    except PermissionError:
        logger.error(f"Permission denied for port {port}. Try running as root or use port > 1024.")
        sys.exit(1)
    except OSError as e:
        logger.error(f"Cannot bind to port {port}: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
