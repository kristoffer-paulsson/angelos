import ipaddress
import socket

"""
(
    (
        [
            ip for ip in socket.gethostbyname_ex(socket.gethostname())[2] if not ip.startswith("127.")
        ] or [
            [
                (
                    s.connect(("1.1.1.1", 1)), s.getsockname()[0], s.close()
                ) for s in [
                    socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            ]
        ][0][1]
    ]
) + ["127.0.0.1"])[0]
"""

# print([ip for ip in socket.gethostbyname_ex(socket.gethostname())[2] if not ip.startswith("127.")])





address = set()

try:
    for ip in socket.gethostbyname_ex(socket.gethostname())[2]:
        if not ip.startswith("127."):
            try:
                address.add(ipaddress.ip_address(ip))
            except ValueError:
                continue
            else:
                break
except socket.gaierror:
    pass

for sock in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]:
    try:
        sock.connect(("1.1.1.1", 1))
        address.add(ipaddress.ip_address(sock.getsockname()[0]))
        sock.close()
    except ValueError:
        continue
    else:
        break

address.add(ipaddress.ip_address("127.0.0.1"))

print(address)

