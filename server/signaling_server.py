"""
Leichtgewichtiger WebSocket-Signaling-Server fuer "Uriges Doppelkopf".
Laeuft lokal auf Port 8765 (oder PORT env) und hinter einem TLS-Reverse-Proxy
(Railway / Fly.io / Nginx / Caddy) ueber WSS (Port 443) fuer eduroam / Hochschul-WLAN!

Protokoll (JSON-Nachrichten):
- Client -> Server:
  {"type": "list_rooms"}
  {"type": "create_room", "host_name": "...", "rules_preset": "...", "max_players": 4}
  {"type": "join_room", "room_code": "ABCD", "player_name": "...", "reconnect_token": "..."}
  {"type": "signal", "target_peer": 1, "kind": "offer"|"answer"|"ice", "payload": {...}}
  {"type": "relay_packet", "target_peer": 1, "payload": {...}} # Fallback falls WebRTC ICE scheitert
- Server -> Client:
  {"type": "room_list", "rooms": [...]}
  {"type": "room_created", "room_code": "ABCD", "peer_id": 1}
  {"type": "room_joined", "room_code": "ABCD", "peer_id": 2, "host_peer_id": 1, "reconnect_token": "..."}
  {"type": "peer_joined", "peer_id": 2, "player_name": "..."}
  {"type": "peer_left", "peer_id": 2}
  {"type": "signal", "from_peer": 1, "kind": "...", "payload": {...}}
  {"type": "relay_packet", "from_peer": 1, "payload": {...}}
  {"type": "error", "message": "..."}
"""

from __future__ import annotations

import asyncio
import base64
import hashlib
import json
import os
import random
import secrets
import struct
import time
from typing import Any, Dict, Optional, Set

WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


class WebSocketClient:
    def __init__(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        self.reader = reader
        self.writer = writer
        self.peer_id: int = 0
        self.room_code: str = ""
        self.player_name: str = "Spieler"
        self.reconnect_token: str = secrets.token_hex(8)
        self.closed = False

    async def send_json(self, data: Dict[str, Any]) -> None:
        if self.closed:
            return
        payload = json.dumps(data, ensure_ascii=False).encode("utf-8")
        frame = bytearray()
        frame.append(0x81)  # FIN + text frame
        length = len(payload)
        if length < 126:
            frame.append(length)
        elif length < 65536:
            frame.append(126)
            frame.extend(struct.pack("!H", length))
        else:
            frame.append(127)
            frame.extend(struct.pack("!Q", length))
        frame.extend(payload)
        try:
            self.writer.write(bytes(frame))
            await self.writer.drain()
        except OSError:
            self.closed = True

    async def read_text_frame(self) -> Optional[str]:
        while not self.closed:
            header = await self.reader.readexactly(2)
            b1, b2 = header[0], header[1]
            opcode = b1 & 0x0F
            masked = (b2 & 0x80) != 0
            length = b2 & 0x7F
            if length == 126:
                length = struct.unpack("!H", await self.reader.readexactly(2))[0]
            elif length == 127:
                length = struct.unpack("!Q", await self.reader.readexactly(8))[0]
            mask_key = await self.reader.readexactly(4) if masked else b""
            data = bytearray(await self.reader.readexactly(length))
            if masked:
                for i in range(length):
                    data[i] ^= mask_key[i % 4]
            if opcode == 0x8:  # Close
                self.closed = True
                return None
            if opcode == 0x9:  # Ping -> Pong
                pong = bytearray([0x8A, len(data)]) + data
                self.writer.write(bytes(pong))
                await self.writer.drain()
                continue
            if opcode == 0xA:  # Pong
                continue
            if opcode == 0x1:  # Text
                return data.decode("utf-8", errors="replace")
        return None


class Room:
    def __init__(self, code: str, host: WebSocketClient, host_name: str, preset: str, max_players: int) -> None:
        self.code = code
        self.host = host
        self.host_name = host_name
        self.preset = preset
        self.max_players = max_players
        self.created_at = time.time()
        self.next_peer_id = 2
        self.peers: Dict[int, WebSocketClient] = {1: host}
        host.peer_id = 1
        host.room_code = code
        host.player_name = host_name


ROOMS: Dict[str, Room] = {}
ALL_CLIENTS: Set[WebSocketClient] = set()


def _gen_room_code() -> str:
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    for _ in range(50):
        code = "".join(random.choice(alphabet) for _ in range(4))
        if code not in ROOMS:
            return code
    return secrets.token_hex(2).upper()


async def handle_message(client: WebSocketClient, msg: Dict[str, Any]) -> None:
    mtype = str(msg.get("type", ""))
    if mtype == "list_rooms":
        items = [
            {
                "room_code": r.code,
                "host_name": r.host_name,
                "preset": r.preset,
                "players": len(r.peers),
                "max_players": r.max_players,
            }
            for r in ROOMS.values()
        ]
        await client.send_json({"type": "room_list", "rooms": items})

    elif mtype == "create_room":
        code = _gen_room_code()
        host_name = str(msg.get("host_name", "Gastgeber"))[:24]
        preset = str(msg.get("rules_preset", "Kneipen-Standard"))
        max_players = int(msg.get("max_players", 4))
        room = Room(code, client, host_name, preset, max_players)
        ROOMS[code] = room
        await client.send_json({"type": "room_created", "room_code": code, "peer_id": 1})

    elif mtype == "join_room":
        code = str(msg.get("room_code", "")).strip().upper()
        room = ROOMS.get(code)
        if not room:
            await client.send_json({"type": "error", "message": f"Tisch '{code}' nicht gefunden."})
            return
        if len(room.peers) >= room.max_players:
            await client.send_json({"type": "error", "message": f"Tisch '{code}' ist bereits voll."})
            return
        peer_id = room.next_peer_id
        room.next_peer_id += 1
        client.peer_id = peer_id
        client.room_code = code
        client.player_name = str(msg.get("player_name", f"Spieler {peer_id}"))[:24]
        room.peers[peer_id] = client

        await client.send_json(
            {
                "type": "room_joined",
                "room_code": code,
                "peer_id": peer_id,
                "host_peer_id": 1,
                "reconnect_token": client.reconnect_token,
            }
        )
        await room.host.send_json(
            {
                "type": "peer_joined",
                "peer_id": peer_id,
                "player_name": client.player_name,
            }
        )

    elif mtype in ("signal", "relay_packet"):
        room = ROOMS.get(client.room_code)
        if not room:
            return
        target_id = int(msg.get("target_peer", 0))
        target = room.peers.get(target_id)
        if target:
            fwd = dict(msg)
            fwd["from_peer"] = client.peer_id
            await target.send_json(fwd)


async def handle_connection(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
    try:
        raw_req = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), timeout=10.0)
    except Exception:
        writer.close()
        return

    req_text = raw_req.decode("utf-8", errors="replace")
    headers: Dict[str, str] = {}
    for line in req_text.split("\r\n")[1:]:
        if ":" in line:
            k, v = line.split(":", 1)
            headers[k.strip().lower()] = v.strip()

    ws_key = headers.get("sec-websocket-key")
    if not ws_key:
        # Simple healthcheck HTTP response for Render/Railway/Fly
        body = b"Uriges Doppelkopf WSS Signaling OK"
        resp = (
            b"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n"
            + f"Content-Length: {len(body)}\r\n\r\n".encode("ascii")
            + body
        )
        writer.write(resp)
        await writer.drain()
        writer.close()
        return

    accept_hash = base64.b64encode(
        hashlib.sha1((ws_key + WS_GUID).encode("ascii")).digest()
    ).decode("ascii")
    handshake = (
        "HTTP/1.1 101 Switching Protocols\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Accept: {accept_hash}\r\n\r\n"
    ).encode("ascii")
    writer.write(handshake)
    await writer.drain()

    client = WebSocketClient(reader, writer)
    ALL_CLIENTS.add(client)
    try:
        while not client.closed:
            text = await client.read_text_frame()
            if text is None:
                break
            try:
                msg = json.loads(text)
            except json.JSONDecodeError:
                continue
            if isinstance(msg, dict):
                await handle_message(client, msg)
    except (asyncio.IncompleteReadError, ConnectionResetError, OSError):
        pass
    finally:
        client.closed = True
        ALL_CLIENTS.discard(client)
        room = ROOMS.get(client.room_code)
        if room:
            room.peers.pop(client.peer_id, None)
            if client.peer_id == 1:
                for p in list(room.peers.values()):
                    await p.send_json({"type": "error", "message": "Gastgeber hat den Tisch geschlossen."})
                ROOMS.pop(room.code, None)
            else:
                await room.host.send_json({"type": "peer_left", "peer_id": client.peer_id})
        writer.close()


async def main() -> None:
    port = int(os.environ.get("PORT", "8765"))
    server = await asyncio.start_server(handle_connection, "0.0.0.0", port)
    print(f"Signaling server listening on ws://0.0.0.0:{port}")
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
