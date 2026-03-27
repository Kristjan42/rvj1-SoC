import sys
sys.path.append("/foss/designs/rvj1-SoC/cocotb/")
import soc_tb_lib
from soc_tb_lib.base import get_test_runner, WAVES
from soc_tb_lib.memory_device import Memory_device 

import forastero
from forastero import DriverEvent, SeqContext
from forastero import BaseBench
from forastero import BaseBench, IORole, BaseDriver, BaseMonitor, BaseIO, io_suffix_style
from forastero.monitor import MonitorEvent
from forastero.driver import DriverEvent
from cocotb.triggers import RisingEdge, ClockCycles
from forastero_io import mapped

from functools import partial

def test_mapped_slave_runner():
    runner = get_test_runner("mapped_slave_testing_module")
    runner.test(hdl_toplevel="mapped_slave_testing_module",test_module = "test_slave_uart", waves=WAVES)

class MappedSlaveTB(BaseBench):
    def __init__(self, dut):
        super().__init__(dut, clk=dut.clk_i, rst=dut.rstn_i, rst_active_high=False)

        self.mmio_device = Memory_device(self)
        self.request_backpressure_func = partial(MappedSlaveTB.const_backpressure, cycles=0)
        self.response_backpressure_func = partial(MappedSlaveTB.const_backpressure, cycles=0)
        self.master_delay_func = partial(MappedSlaveTB.const_backpressure, cycles=0)
        self.slave_delay_func = partial(MappedSlaveTB.const_backpressure, cycles=0)
    # ---------- IO ----------

        mapped_request_io = mapped.MappedRequestIO(dut, "mapped", IORole.RESPONDER)
        mapped_response_io = mapped.MappedResponseIO(dut, "mapped", IORole.INITIATOR)
    # ---------- Drivers ----------

        # Request channel drivers
        self.register(  # MAPPED M->S request signals driver
            "mapped_request_driver",
            mapped.MappedRequestInitiator(self, mapped_request_io, self.clk, self.rst)
        )
        self.mapped_request_driver.subscribe(DriverEvent.ENQUEUE, self.push_request_reference)
        self.mapped_request_driver.subscribe(DriverEvent.ENQUEUE, self.drive_request_backpressure)

        self.register(  # MAPPED M<-S request backpressure ready signal driver
            "mapped_request_backpressure_driver",
            mapped.MappedRequestResponder(self, mapped_request_io, self.clk, self.rst)
        )

        # Response channel drivers 
        self.register(  # MAPPED M<-S response signals driver
            "mapped_response_driver",
            mapped.MappedResponseInitiator(self, mapped_response_io, self.clk, self.rst)
        )
        self.mapped_response_driver.subscribe(DriverEvent.ENQUEUE, self.push_response_reference)
        self.mapped_response_driver.subscribe(DriverEvent.ENQUEUE, self.drive_response_backpressure)

        self.register(  # MAPPED M->S response backpressure ready signal driver
            "mapped_response_backpressure_signal",
            mapped.MappedResponseResponder(self, mapped_response_io, self.clk, self.rst)
        )
    # ---------- Monitors ----------

        self.register(  # MAPPED monitor M->S>(monitor) for reading request channel signals
            "mapped_request_monitor",
            mapped.MappedRequestMonitor(self, mapped_request_io, self.clk, self.rst)
        )
        self.mapped_request_monitor.subscribe(MonitorEvent.CAPTURE, self.drive_response)

        self.register(  # MAPPED monitor (monitor)<M<-S for reading response channel signals
            "mapped_response_monitor",
            mapped.MappedResponseMonitor(self, mapped_response_io, self.clk, self.rst)
        )
# ---------- Subscriber methods ----------

    # Monitor reference push methods
    def push_request_reference( # Pushes the request transaction signals reference from request driver input to the request monitor for comparison
        self, driver:mapped.MappedRequestInitiator, event:DriverEvent , obj:mapped.MappedRequest
    ):
        self.scoreboard.channels["mapped_request_monitor"].push_reference(
            mapped.MappedRequest(   # Transaction signals to push and compare 
                address=obj.address,
                mode=obj.mode,
                data=obj.data,
                strobe=obj.strobe
            )
        )

    def push_response_reference(    # Pushes the response transaction signals reference from response driver input to the response monitor for comparison
        self, driver:mapped.MappedResponseInitiator, event:DriverEvent, obj:mapped.MappedResponse
    ):
        self.scoreboard.channels["mapped_response_monitor"].push_reference(
            mapped.MappedResponse(  # Transaction signals to push and compare
                data=obj.data,
                error=obj.error
            )
        )

    # Response driver drive methods
    def drive_response( # Drives the response transaction upon the monitor capture of the request transaction
            self, monitor:mapped.MappedRequestMonitor, event:MonitorEvent, obj:mapped.MappedRequest
    ):
        match obj.mode: # Check if request was a READ or WRITE transaction
            case mapped.MappedAccess.READ:  # On READ, read data from address in mmio device
                read = self.mmio_device.read(obj.address)
                err = 1 if read is None else 0
                self.mapped_response_driver.enqueue(# Drive the read response transaction signals (data, error) 
                    mapped.MappedResponse(
                        data=read,
                        valid=1,
                        valid_delay=self.slave_delay_func(self),
                        error=err
                    )
                )
            case mapped.MappedAccess.WRITE: # On WRITE, write the data to address in mmio device
                err = self.mmio_device.write(obj.address, obj.data, obj.strobe)
                self.mapped_response_driver.enqueue(# Drive the write response transaction signals (error)
                    mapped.MappedResponse(
                        data=0,
                        valid=1,
                        valid_delay=self.slave_delay_func(self),
                        error=err
                    )
                )
    
    # Backpressure drivers drive methods

    def drive_request_backpressure( # Drives the ready signal M<-S
            self, driver:mapped.MappedRequestInitiator, event:DriverEvent , obj:mapped.MappedRequest
    ):
        self.mapped_request_backpressure_driver.enqueue(# Drives ready low for the specified duration of cycles
            mapped.MappedBackpressure(
                ready=0,
                cycles=self.request_backpressure_func(self)
            ) 
        )
        self.mapped_request_backpressure_driver.enqueue(# Drives ready high for 1 cycle to complete the transaction
            mapped.MappedBackpressure(
                ready=1,
                cycles=1
            )
        )
        #while not self.mapped_request_io.get("valid"):  # Waits for valid to be set if not already
        #    continue
        
    def drive_response_backpressure( # Drives the ready signal M->S
            self, driver:mapped.MappedResponseInitiator, event:DriverEvent , obj:mapped.MappedResponse
    ):
        self.mapped_response_backpressure_driver.enqueue(# Drives ready low for the specified duration of cycles
            mapped.MappedBackpressure(
                ready=0,
                cycles=self.response_backpressure_func(self)
            ) 
        )
        self.mapped_response_backpressure_driver.enqueue(# Drives ready high for 1 cycle to complete the transaction
            mapped.MappedBackpressure(
                ready=1,
                cycles=1
            )
        )

# ---------- Backpressure methods ----------

    # Returns a constant value
    def const_backpressure(self, cycles: int):
        return cycles

    # Returns a random value in provided array of values
    def random_backpressure(self, data: list[int]):
        return data[self.random.randrange(0, len(data))]
        

# ---------- Sequence signal values generation methods ----------
        
    def gen_linear_address_seq(self, start: int, offsets: list[int]) -> list[int]:
        addresses: list[int] = []
        for offset in offsets:
            addresses.append(
                start + offset
            ) 
        return addresses
    
    def gen_random_address_seq(self, start: int, offsets: list[int], repetitions: int, seed: int) -> list[int]:
        self.random.seed(seed)
        addresses: list[int] = []
        for _ in range(repetitions):
            addresses.append(
                start + offsets[self.random.randrange(0, len(offsets))]
            ) 
        return addresses
    
    def gen_linear_data_seq(self, start:int, amount:int) -> list[int]:
        data: list[int] = []
        for i in range(amount):
            data.append(
                start + 1
            )

    def gen_random_data_seq(self, count:int, seed:int) -> list[int]:
        self.random.seed(seed)
        data: list[int] = []
        for _ in range(count):
            data.append(
                self.random.randint(0, 0x7fffffff)
            )

    def gen_random_strobe_seq(self, count:int, seed:int) -> list[int]:
        self.random.seed(seed)
        strobe: list[int] = []
        for _ in range(count):
            strobe.append(
                self.random.randint(0, 15)
            )
            

if __name__ == "__main__":
    test_mapped_slave_runner()