from dummy.stub import StubClient, StubServer

from dummy.support import run_async
from dummy.testing import BaseTestNetwork


class TestEvent(BaseTestNetwork):
    pref_connectable = True

    @run_async
    async def test_network(self):
        try:
            # self.assertIsInstance(self.server.app, StubServer)
            # self.assertIsInstance(self.client.app, StubClient)
            await self.server.app.listen()
            client = await self.client.app.connect()
            await client.mail()
        except Exception as e:
            self.fail(e)
