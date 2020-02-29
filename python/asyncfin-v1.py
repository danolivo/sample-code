"""

	Correct tasks finalization. Variant 1. Do it by SIGTERM interception.

"""

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
    
    async def waiter(self):
        tasks = [t for t in asyncio.Task.all_tasks() if t is not asyncio.Task.current_task()]
        await asyncio.gather(*tasks)

        self.loop.remove_signal_handler(signal.SIGTERM)
        self.loop.stop()

    def sigterm_handler(self):
        print("Catch SIGTERM")
        self.running = False
        self.loop.create_task(self.waiter())

    def run(self):
        self.loop = asyncio.get_event_loop()
        self.loop.add_signal_handler(signal.SIGTERM, self.sigterm_handler)    
        for j in range(3):
            self.loop.create_task(self.test(j))

        try:
            self.loop.run_forever()
        finally:
            print("Finally section")
            self.loop.close()

    def bgrun(self):    
        evloop_process = multiprocessing.Process(target=self.run, args=())
        evloop_process.start()
        time.sleep(4)
        evloop_process.terminate()
        evloop_process.join()

client = Client();
client.bgrun();
