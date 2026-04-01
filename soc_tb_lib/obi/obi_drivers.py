from cocotb.triggers import ClockCycles, RisingEdge
from forastero.driver import BaseDriver
from forastero.monitor import BaseMonitor

from .obi_transactions import ObiAccess, ObiRequest, ObiResponse, ObiBackpressure

class ObiResponseDriver(BaseDriver):
    async def drive(self, transaction: ObiResponse):
        # Setup signals
        self.io.set("rdata", transaction.obi_rdata)
        self.io.set("rerr", transaction.obi_rerr)
        self.io.set("rid", transaction.obi_rid)
        # Drive valid after delay if set
        if transaction.valid_delay:
            await ClockCycles(self.clk, transaction.valid_delay)
        self.io.set("rvalid", 1)
        # Wait for incoming rready signal to be accepted
        while True:
            await(RisingEdge(self.clk))
            if self.io.get("rready"):
                break
        # Set rvalid signal to low after transaction completed
        self.io.set("rvalid", 0)

class ObiRequestBackpressureDriver(BaseDriver):
    async def drive(self, transaction: ObiBackpressure):
        self.io.set("agnt", transaction.ready)
        await ClockCycles(self.clk, transaction.cycles)

class ObiResponseBackpressureDriver(BaseDriver):
    async def drive(self, transaction: ObiBackpressure):
        self.io.set("rready", transaction.ready)
        await ClockCycles(self.clk, transaction.cycles)