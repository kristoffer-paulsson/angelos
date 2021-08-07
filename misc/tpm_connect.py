"""Attempt to connect to a TPM2 simulator."""
import asyncio


async def connect(message):
    """Connect to a server and try."""
    reader, writer = await asyncio.open_connection(
        '127.0.0.1', 2321)

    print(f'Send: {message!r}')
    writer.write(message.encode())
    await writer.drain()

    data = await reader.read(1024)
    print(f'Received: {data.decode()!r}')

    print('Close the connection')
    writer.close()
    await writer.wait_closed()


if __name__ == "__main__":
    asyncio.run(connect("Hello, world!"))
