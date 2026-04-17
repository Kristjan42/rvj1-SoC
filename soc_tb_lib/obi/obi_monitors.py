from cocotb.triggers import ClockCycles, RisingEdge
from forastero.driver import BaseDriver
from forastero.monitor import BaseMonitor

from .obi_transactions import ObiAccess, ObiRequest, ObiResponse

class ObiRequestMonitor(BaseMonitor):
    async def monitor(self, capture):
        while True:
            await RisingEdge(self.clk)
            if self.rst.value == 0:
                await RisingEdge(self.clk)
                continue
            #if self.io.get("areq") and self.io.get("agnt"):
            if self.io.get("areq") and self.io.get("agnt"):
                is_write = self.io.get("awe") == 1
                awdata = self.io.get("awdata") if is_write else 0
                capture(
                    ObiRequest(
                        obi_aadr=self.io.get("aadr"),
                        obi_awe=is_write,
                        obi_abe=self.io.get("abe"),
                        obi_awdata=awdata,
                        obi_mid=self.io.get("mid"),
                        obi_aid=self.io.get("aid")
                    )
                )