"""

	Correct tasks finalization. Variant 2. Send signal by AioPipe message.

"""

import aiopg
import aioprocessing
import asyncio
import multiprocessing
import random
import signal
import time

class Client(object):
    def __init__(self):
        self.running = True

    @asyncio.coroutine
    async def test(self, i):
        while self.running:
            val = random.randint(0, 4)
            print ("Do work. thread: {0}, timeout: {1}".format(i, val))
            await asyncio.sleep(val)

        print ("End of thread: {0}".format(i))

    @asyncio.coroutine
    async def finalizer(self):
        print("Finalizer task started")
        while self.running:
            msg = await self.child_pipe.coro_recv()
            if msg == "exit":
                self.running = False

        tasks = [t for t in asyncio.Task.all_tasks() if t is not asyncio.Task.current_task()]
        await asyncio.gather(*tasks)

        self.loop.stop()
        print("Finalizer task finished")

    def run(self):
        self.loop = asyncio.get_event_loop()
        for j in range(3):
            self.loop.create_task(self.test(j))
        self.loop.create_task(self.finalizer())

        try:
            self.running = True
            self.loop.run_forever()
        finally:
            print("Finally section")
            self.loop.close()

    def bgrun(self):    
        self.parent_pipe, self.child_pipe = aioprocessing.AioPipe()
        evloop_process = multiprocessing.Process(target=self.run, args=())
        evloop_process.start()
        time.sleep(4)
        self.parent_pipe.send('exit')
        evloop_process.join()

client = Client();
client.bgrun();
