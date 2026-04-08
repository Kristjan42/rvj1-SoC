import sys
sys.path.append('../../../soc_tb_lib')
from base import get_test_runner, WAVES
from memory_device import Memory_device, gen_memory_data
import obi

import forastero
from forastero import DriverEvent, SeqContext
from forastero import BaseBench
from forastero import BaseBench, IORole, BaseDriver, BaseMonitor, BaseIO, io_suffix_style
from forastero.monitor import MonitorEvent
from forastero.driver import DriverEvent
from cocotb.triggers import RisingEdge, ClockCycles
from forastero_io import mapped

# TODO fix circular dependency
#from mapped_obi_sequences import linear_read_seq

from functools import partial

import math




from cocotb.triggers import ClockCycles
from forastero.driver import DriverEvent
from forastero.sequence import SeqContext, SeqProxy

from forastero_io.mapped.request import MappedRequestInitiator, MappedRequestResponder
from forastero_io.mapped.response import MappedResponseInitiator, MappedResponseResponder
from forastero_io.mapped.transaction import MappedAccess, MappedBackpressure, MappedRequest, MappedResponse



def test_obi_crossbar_runner():
    runner = get_test_runner("obi_xbar_testing_module")
    runner.test(hdl_toplevel="obi_xbar_testing_module",test_module = "test_obi_crossbar", waves=WAVES)

class MappedResponseMonitor(BaseMonitor):
    async def monitor(self, capture):
        while True:
            await RisingEdge(self.clk)
            if self.rst.value == 0:
                await RisingEdge(self.clk)
                continue
            if self.io.get("valid") and self.io.get("ready"):
                tran = MappedResponse(
                    ident=self.io.get("id", 0),
                    data=self.io.get("data", 0),
                    error=self.io.get("error", 0),
                )
                capture(tran)

BaseIO.DEFAULT_IO_STYLE = io_suffix_style

class ObiXbarTB(BaseBench):
    def __init__(self, dut):
        super().__init__(dut, clk=dut.clk_i, rst=dut.rstn_i, rst_active_high=False)

        self.subordinates = 3

        self.mmio_device = Memory_device(self)

        self.ifu_response_backpressure_func = partial(ObiXbarTB.const_backpressure, cycles=0)
        self.lsu_response_backpressure_func = partial(ObiXbarTB.const_backpressure, cycles=0)

        self.s0_request_backpressure_func = partial(ObiXbarTB.const_backpressure, cycles=0)
        self.s1_request_backpressure_func = partial(ObiXbarTB.const_backpressure, cycles=0)
        self.s2_request_backpressure_func = partial(ObiXbarTB.const_backpressure, cycles=0)

        self.master_delay_func = partial(ObiXbarTB.const_backpressure, cycles=0)
        self.slave_delay_func = partial(ObiXbarTB.const_backpressure, cycles=0)

        self.response_window = 100
        self.request_window = 100
    # ---------- IO ----------

        # IFU MAPPED io
        mapped_request_ifu_io = mapped.MappedRequestIO(dut, "ifu_req", IORole.RESPONDER) # Init io IFU->M0 as driver is MAPPED request driver
        mapped_response_ifu_io = mapped.MappedResponseIO(dut, "ifu_rsp", IORole.INITIATOR) # Rsp io IFU<-M0 as MAPPED monitor is on IFU
        #mapped_response_bp_ifu_io = mapped.MappedResponseIO(dut, "ifu", IORole.INITIATOR) # Init io IFU->M0 as driver is MAPPED response backpressure driver

        # LSU MAPPED io
        mapped_request_lsu_io = mapped.MappedRequestIO(dut, "lsu_req", IORole.RESPONDER) # Init io LSU->M1 as driver is MAPPED request driver
        mapped_response_lsu_io = mapped.MappedResponseIO(dut, "lsu_rsp", IORole.INITIATOR) # Rsp io LSU<-M1 as MAPPED monitor is on LSU

        # M0-S0 OBI io
        obi_request_00_io = obi.ObiRequestIO(dut, "obi_00", IORole.INITIATOR ) # Rsp io M0->S0 as OBI monitor is on S0 
        obi_response_00_io = obi.ObiResponseIO(dut, "obi_00", IORole.RESPONDER) # Init io M0<-S0 as driver is OBI response driver

        # M1-S0 OBI io
        obi_request_11_io = obi.ObiRequestIO(dut, "obi_10", IORole.INITIATOR ) # Rsp io M1->S1 as OBI monitor is on S1 
        obi_response_11_io = obi.ObiResponseIO(dut, "obi_10", IORole.RESPONDER) # Init io M1<-S1 as driver is OBI response driver

        # M1-S1 OBI io
        obi_request_12_io = obi.ObiRequestIO(dut, "obi_11", IORole.INITIATOR ) # Rsp io M1->S2 as OBI monitor is on S2 
        obi_response_12_io = obi.ObiResponseIO(dut, "obi_11", IORole.RESPONDER) # Init io M1<-S2 as driver is OBI response driver

    # ---------- Drivers ----------

        # IFU MAPPED request channel drivers 

        self.register(  # MAPPED IFU->M0 request signals driver
            "ifu_mapped_request_driver",
            mapped.MappedRequestInitiator(self, mapped_request_ifu_io, self.clk, self.rst)
        )
        #self.mapped_request_driver.subscribe(DriverEvent.ENQUEUE, self.push_request_reference)
        #self.mapped_request_driver.subscribe(DriverEvent.ENQUEUE, self.drive_request_backpressure)
        self.ifu_mapped_request_driver.subscribe(DriverEvent.ENQUEUE, self.ifu_push_request_reference)
        self.ifu_mapped_request_driver.subscribe(DriverEvent.PRE_DRIVE, self.drive_request_backpressure_s0)

        # IFU MAPPED response channel drivers

        self.register(  # MAPPED IFU->M0 response backpressure signal driver
            "ifu_mapped_response_backpressure_driver",
            mapped.MappedResponseResponder(self, mapped_response_ifu_io, self.clk, self.rst)
        )

        # LSU MAPPED request channel drivers

        self.register(  # MAPPED LSU->M1 request signal driver
            "lsu_mapped_request_driver",
            mapped.MappedRequestInitiator(self, mapped_request_lsu_io, self.clk, self.rst)
        )
        self.lsu_mapped_request_driver.subscribe(DriverEvent.ENQUEUE, self.lsu_push_request_reference)
        # TODO not the best to sub both, better to check address and then drive 1, this works however may not yield reproducible randoms  
        self.lsu_mapped_request_driver.subscribe(DriverEvent.PRE_DRIVE, self.drive_request_backpressure_s1)
        self.lsu_mapped_request_driver.subscribe(DriverEvent.PRE_DRIVE, self.drive_request_backpressure_s2)

        # LSU MAPPED response channel drivers

        self.register(  # MAPPED LSU->M1 response backpressure signal driver
            "lsu_mapped_response_backpressure_driver",
            mapped.MappedResponseResponder(self, mapped_response_lsu_io, self.clk, self.rst)
        )

        # RAM-A (S0) OBI request channel drivers

        self.register(  # OBI M0<-S0 request backpressure signal driver
            "s0_obi_request_backpressure_driver",
            obi.ObiRequestBackpressureDriver(self, obi_request_00_io, self.clk, self.rst)
        )

        # RAM-A (S0) OBI response channel drivers

        self.register( # OBI M0<-S0 response signal driver
            "s0_obi_response_driver",
            obi.ObiResponseDriver(self, obi_response_00_io, self.clk, self.rst)
        )
        self.s0_obi_response_driver.subscribe(DriverEvent.PRE_DRIVE, self.drive_response_backpressure_ifu)
        self.s0_obi_response_driver.subscribe(DriverEvent.PRE_DRIVE, self.push_response_reference)

        # RAM-B (S1) OBI request channel drivers

        self.register(  # OBI M1<-S1 request backpressure signal driver
            "s1_obi_request_backpressure_driver",
            obi.ObiRequestBackpressureDriver(self, obi_request_11_io, self.clk, self.rst)
        )

        # RAM-B (S1) OBI response channel drivers

        self.register( # OBI M1<-S1 response signal driver
            "s1_obi_response_driver",
            obi.ObiResponseDriver(self, obi_response_11_io, self.clk, self.rst)
        )
        self.s1_obi_response_driver.subscribe(DriverEvent.PRE_DRIVE, self.drive_response_backpressure_lsu)
        self.s1_obi_response_driver.subscribe(DriverEvent.PRE_DRIVE, self.push_response_reference)

        # UART (S2) OBI request channel drivers

        self.register(  # OBI M1<-S2 request backpressure signal driver
            "s2_obi_request_backpressure_driver",
            obi.ObiRequestBackpressureDriver(self, obi_request_12_io, self.clk, self.rst)
        )

        # UART (S2) OBI response channel drivers

        self.register( # OBI M1<-S2 response signal driver
            "s2_obi_response_driver",
            obi.ObiResponseDriver(self, obi_response_12_io, self.clk, self.rst)
        )
        self.s2_obi_response_driver.subscribe(DriverEvent.PRE_DRIVE, self.drive_response_backpressure_lsu)
        self.s2_obi_response_driver.subscribe(DriverEvent.PRE_DRIVE, self.push_response_reference)

    # ---------- Monitors ----------
        
        # IFU monitor
        self.register(  # MAPPED monitor (monitor)<IFU<-M0 for reading response channel signals
            "ifu_mapped_response_monitor",
            MappedResponseMonitor(self, mapped_response_ifu_io, self.clk, self.rst),
            sb_match_window=self.response_window
        )

        # LSU monitor
        self.register(  # MAPPED monitor (monitor)<LSU<-M1 for reading response channel signals
            "lsu_mapped_response_monitor",
            MappedResponseMonitor(self, mapped_response_lsu_io, self.clk, self.rst),
            sb_match_window=self.response_window
        )

        # RAM-A (S0) monitor
        self.register(  # OBI monitor M0->S0>(monitor) for reading request channel signals
            "s0_obi_request_monitor",
            obi.ObiRequestMonitor(self, obi_request_00_io, self.clk, self.rst)
        )
        self.s0_obi_request_monitor.subscribe(MonitorEvent.CAPTURE, self.drive_response_s0)

        # RAM-B (S1) monitor
        self.register(  # OBI monitor M1->S1>(monitor) for reading request channel signals
            "s1_obi_request_monitor",
            obi.ObiRequestMonitor(self, obi_request_11_io, self.clk, self.rst)
        )
        self.s1_obi_request_monitor.subscribe(MonitorEvent.CAPTURE, self.drive_response_s1)

        # UART (S2) monitor
        self.register(  # OBI monitor M1->S2>(monitor) for reading request channel signals
            "s2_obi_request_monitor",
            obi.ObiRequestMonitor(self, obi_request_12_io, self.clk, self.rst)
        )
        self.s2_obi_request_monitor.subscribe(MonitorEvent.CAPTURE, self.drive_response_s2)

# ---------- Subscriber methods ----------

    # Monitor reference push methods

    def ifu_push_request_reference( # Pushes the request transaction signals reference from request driver input to the request monitor for comparison
        self, driver:mapped.MappedRequestInitiator, event:DriverEvent , obj:mapped.MappedRequest
    ):
        monitor = "s" + self.ifu_request_decode(obj.address) + "_obi_request_monitor"
        self.scoreboard.channels[monitor].push_reference(
            obi.ObiRequest(   # Transaction signals to push and compare 
                obi_aadr=obj.address,
                obi_awe=(obj.mode - 1), # mapped READ value is 1 where obi READ is 0 (diffrence in the way classes were written)
                obi_abe=obj.strobe,
                obi_awdata=obj.data,
                obi_aid=obj.ident,    
                obi_mid=0           
            )
        )

    def lsu_push_request_reference( # Pushes the request transaction signals reference from request driver input to the request monitor for comparison
        self, driver:mapped.MappedRequestInitiator, event:DriverEvent , obj:mapped.MappedRequest
    ):
        monitor = "s" + self.lsu_request_decode(obj.address) + "_obi_request_monitor"
        self.log.info(msg=monitor + f" pushed reference address: " + '{:032b}'.format(obj.address))
        self.scoreboard.channels[monitor].push_reference(
            obi.ObiRequest(   # Transaction signals to push and compare 
                obi_aadr=obj.address,
                obi_awe=(obj.mode - 1), # mapped READ value is 1 where obi READ is 0 (diffrence in the way classes were written)
                obi_abe=obj.strobe,
                obi_awdata=obj.data,
                obi_aid=obj.ident,    
                obi_mid=1           
            )
        )

    def push_response_reference(    # Pushes the response transaction signals reference from response driver input to the response monitor for comparison
        self, driver:obi.ObiResponseDriver, event:DriverEvent, obj:obi.ObiResponse
    ):
        if obj.obi_mid == 0:
            manager = "ifu"
            self.log.info(msg=f"Pushed IFU response to scoreboard")
        elif obj.obi_mid == 1:
            manager = "lsu"
            self.log.info(msg=f"Pushed LSU response to scoreboard")
        monitor = manager + "_mapped_response_monitor"
        self.scoreboard.channels[monitor].push_reference(
            mapped.MappedResponse(  # Transaction signals to push and compare
                ident=obj.obi_rid,
                data=obj.obi_rdata,
                error=obj.obi_rerr,
                valid=True
            )
        )
        

    # Response driver drive methods

    def drive_response_s0( # Drives the response transaction upon the monitor capture of the request transaction
            self, monitor:obi.ObiRequestMonitor, event:MonitorEvent, obj:obi.ObiRequest
    ):  
        self.log.info(msg=f"Captured request transaction on s0")
        match obj.obi_awe: # Check if request was a READ or WRITE transaction
            case obi.ObiAccess.READ:  # On READ, read data from address in mmio device
                read = self.mmio_device.read(obj.obi_aadr)
                err = 1 if read is None else 0
                self.s0_obi_response_driver.enqueue(# Drive the read response transaction signals (data, error) 
                    obi.ObiResponse(
                        valid_delay=self.slave_delay_func(self),
                        obi_rdata = read,
                        obi_rerr=err,
                        obi_rid=obj.obi_aid,
                        obi_mid=obj.obi_mid
                    )
                )
                self.log.info(msg=f"Driving READ response on s0")
            case obi.ObiAccess.WRITE: # On WRITE, write the data to address in mmio device
                err = self.mmio_device.write(obj.obi_aadr, obj.obi_awdata, obj.obi_abe)
                self.s0_obi_response_driver.enqueue(# Drive the write response transaction signals (error)
                    obi.ObiResponse(
                        valid_delay=self.slave_delay_func(self),
                        obi_rdata = 0,
                        obi_rerr=err,
                        obi_rid=obj.obi_aid,
                        obi_mid=obj.obi_mid
                    )
                )
                self.log.info(msg=f"Driving WRITE response on s0")

    def drive_response_s1( # Drives the response transaction upon the monitor capture of the request transaction
            self, monitor:obi.ObiRequestMonitor, event:MonitorEvent, obj:obi.ObiRequest
    ):
        self.log.info(msg=f"Captured request transaction on s1")
        match obj.obi_awe: # Check if request was a READ or WRITE transaction
            case obi.ObiAccess.READ:  # On READ, read data from address in mmio device
                read = self.mmio_device.read(obj.obi_aadr)
                err = 1 if read is None else 0
                self.s1_obi_response_driver.enqueue(# Drive the read response transaction signals (data, error) 
                    obi.ObiResponse(
                        valid_delay=self.slave_delay_func(self),
                        obi_rdata = read,
                        obi_rerr=err,
                        obi_rid=obj.obi_aid,
                        obi_mid=obj.obi_mid
                    )
                )
                self.log.info(msg=f"Driving READ response on s1")
            case obi.ObiAccess.WRITE: # On WRITE, write the data to address in mmio device
                err = self.mmio_device.write(obj.obi_aadr, obj.obi_awdata, obj.obi_abe)
                self.s1_obi_response_driver.enqueue(# Drive the write response transaction signals (error)
                    obi.ObiResponse(
                        valid_delay=self.slave_delay_func(self),
                        obi_rdata = 0,
                        obi_rerr=err,
                        obi_rid=obj.obi_aid,
                        obi_mid=obj.obi_mid
                    )
                )
                self.log.info(msg=f"Driving WRITE response on s1")

    def drive_response_s2( # Drives the response transaction upon the monitor capture of the request transaction
            self, monitor:obi.ObiRequestMonitor, event:MonitorEvent, obj:obi.ObiRequest
    ):
        self.log.info(msg=f"Captured request transaction on s2")
        match obj.obi_awe: # Check if request was a READ or WRITE transaction
            case obi.ObiAccess.READ:  # On READ, read data from address in mmio device
                read = self.mmio_device.read(obj.obi_aadr)
                err = 1 if read is None else 0
                self.s2_obi_response_driver.enqueue(# Drive the read response transaction signals (data, error) 
                    obi.ObiResponse(
                        valid_delay=self.slave_delay_func(self),
                        obi_rdata = read,
                        obi_rerr=err,
                        obi_rid=obj.obi_aid,
                        obi_mid=obj.obi_mid
                    )
                )
                self.log.info(msg=f"Driving READ response on s2")
            case obi.ObiAccess.WRITE: # On WRITE, write the data to address in mmio device
                err = self.mmio_device.write(obj.obi_aadr, obj.obi_awdata, obj.obi_abe)
                self.s2_obi_response_driver.enqueue(# Drive the write response transaction signals (error)
                    obi.ObiResponse(
                        valid_delay=self.slave_delay_func(self),
                        obi_rdata = 0,
                        obi_rerr=err,
                        obi_rid=obj.obi_aid,
                        obi_mid=obj.obi_mid
                    )
                )
                self.log.info(msg=f"Driving WRITE response on s2")
    
    # Backpressure drivers drive methods
     
    def drive_response_backpressure_ifu( # Drives the ready signal IFU->M0
            self, driver:obi.ObiResponseDriver, event:DriverEvent , obj:obi.ObiResponse
    ):
        self.ifu_mapped_response_backpressure_driver.enqueue(# Drives ready low for the specified duration of cycles
            mapped.MappedBackpressure(
                ready=0,
                cycles=self.ifu_response_backpressure_func(self)
            ) 
        )
        self.ifu_mapped_response_backpressure_driver.enqueue(# Drives ready high for 1 cycle to complete the transaction
            mapped.MappedBackpressure(
                ready=1,
                cycles=1
            )
        )

    def drive_response_backpressure_lsu( # Drives the ready signal LSU->M1
            self, driver:obi.ObiResponseDriver, event:DriverEvent , obj:obi.ObiResponse
    ):
        self.lsu_mapped_response_backpressure_driver.enqueue(# Drives ready low for the specified duration of cycles
            mapped.MappedBackpressure(
                ready=0,
                cycles=self.lsu_response_backpressure_func(self)
            ) 
        )
        self.lsu_mapped_response_backpressure_driver.enqueue(# Drives ready high for 1 cycle to complete the transaction
            mapped.MappedBackpressure(
                ready=1,
                cycles=1
            )
        )

    def drive_request_backpressure_s0( # Drives the agnt signal M0<-S0
            self, driver:mapped.MappedRequestInitiator, event:DriverEvent , obj:mapped.MappedRequest
    ):
        self.log.info(msg=f"Driving s0 request backpressure")
        self.s0_obi_request_backpressure_driver.enqueue(# Drives agnt low for the specified duration of cycles
            obi.ObiBackpressure(
                ready=0,
                cycles=self.s0_request_backpressure_func(self)
            ) 
        )
        self.s0_obi_request_backpressure_driver.enqueue(# Drives agnt high for 1 cycle to complete the transaction
            obi.ObiBackpressure(
                ready=1,
                cycles=1
            )
        )

    def drive_request_backpressure_s1( # Drives the agnt signal M1<-S1
            self, driver:mapped.MappedRequestInitiator, event:DriverEvent , obj:mapped.MappedRequest
    ):
        self.log.info(msg=f"Driving s1 request backpressure")
        self.s1_obi_request_backpressure_driver.enqueue(# Drives agnt low for the specified duration of cycles
            obi.ObiBackpressure(
                ready=0,
                cycles=self.s1_request_backpressure_func(self)
            ) 
        )
        self.s1_obi_request_backpressure_driver.enqueue(# Drives agnt high for 1 cycle to complete the transaction
            obi.ObiBackpressure(
                ready=1,
                cycles=1
            )
        )

    def drive_request_backpressure_s2( # Drives the agnt signal M1<-S1
            self, driver:mapped.MappedRequestInitiator, event:DriverEvent , obj:mapped.MappedRequest
    ):
        self.s2_obi_request_backpressure_driver.enqueue(# Drives agnt low for the specified duration of cycles
            obi.ObiBackpressure(
                ready=0,
                cycles=self.s2_request_backpressure_func(self)
            ) 
        )
        self.s2_obi_request_backpressure_driver.enqueue(# Drives agnt high for 1 cycle to complete the transaction
            obi.ObiBackpressure(
                ready=1,
                cycles=1
            )
        )

# ---------- Decoder methods ----------

    def ifu_request_decode(self, address: int) -> str:
        ifu_decode_dict = {
            0 : "0"
        }
        range = int(math.ceil(math.log2(self.subordinates)))
        binary = '{:032b}'.format(address)
        #self.log.info(msg=f"address:" + str(address))
        self.log.info(msg=f"address in binary:" + binary)
        range_bin = binary[:range]
        self.log.info(msg=f"int of range:" + str(int(range_bin, 2)))
        return ifu_decode_dict[int(range_bin, 2)]
    
    def lsu_request_decode(self, address: int) -> str:
        lsu_decode_dict = {
            0 : "1",
            1 : "2"
        }
        range = int(math.ceil(math.log2(self.subordinates)))
        binary = '{:032b}'.format(address)
        #self.log.info(msg=f"address:" + str(address))
        self.log.info(msg=f"address in binary:" + binary)
        range_bin = binary[:range]
        self.log.info(msg=f"int of range:" + str(int(range_bin, 2)))
        return lsu_decode_dict[int(range_bin, 2)]

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
        return data

    def gen_random_data_seq(self, count:int, seed:int) -> list[int]:
        self.random.seed(seed)
        data: list[int] = []
        for _ in range(count):
            data.append(
                self.random.randint(0, 0x7fffffff)
            )
        return data

    def gen_random_strobe_seq(self, count:int, seed:int) -> list[int]:
        self.random.seed(seed)
        strobe: list[int] = []
        for _ in range(count):
            strobe.append(
                self.random.randint(0, 15)
            )
        return strobe




@forastero.sequence()
@forastero.requires("driver", MappedRequestInitiator)
async def linear_read_seq(
    ctx: SeqContext,
    driver: MappedRequestInitiator,
    tb: ObiXbarTB,
    addresses: list[int] | None = None,
) -> None:
    for i, addr in enumerate(addresses):
        async with ctx.lock(driver):
            driver.enqueue(
                MappedRequest(
                    cycles=0,
                    ident=i+1,
                    address=addr,
                    mode=MappedAccess.READ,
                ),
                DriverEvent.POST_DRIVE
            ).wait()

@forastero.sequence()
@forastero.requires("request_driver", MappedRequestInitiator)
@forastero.requires("request_backpressure_driver", obi.ObiRequestBackpressureDriver)
@forastero.requires("request_monitor", obi.ObiRequestMonitor)
@forastero.requires("response_driver", obi.ObiResponseDriver)
@forastero.requires("response_backpressure_driver", mapped.MappedResponseResponder)
@forastero.requires("response_monitor", MappedResponseMonitor)
async def linear_read_seq_bp(
    ctx: SeqContext,
    request_driver: MappedRequestInitiator,
    request_backpressure_driver: obi.ObiRequestBackpressureDriver,
    request_monitor: obi.ObiRequestMonitor,
    response_driver: obi.ObiResponseDriver,
    response_backpressure_driver: mapped.MappedResponseResponder,
    response_monitor: MappedResponseMonitor,
    backpressure_func: partial,
    tb: ObiXbarTB,
    addresses: list[int] | None = None,
) -> None:
    for i, addr in enumerate(addresses):
        async with ctx.lock(request_driver, request_backpressure_driver, request_monitor, response_driver, response_monitor, response_backpressure_driver):
            request_driver.enqueue(
                MappedRequest(
                    cycles=tb.master_delay_func(tb),
                    ident=i+1,
                    address=addr,
                    mode=MappedAccess.READ
                )
            )
            """
            request_backpressure_driver.enqueue(# Drives agnt low for the specified duration of cycles
                obi.ObiBackpressure(
                    ready=0,
                    cycles=backpressure_func(tb)
                ) 
            )
            request_backpressure_driver.enqueue(# Drives agnt high for 1 cycle to complete the transaction
                obi.ObiBackpressure(
                    ready=1,
                    cycles=1
                ),
                DriverEvent.POST_DRIVE
            )
            """
            await request_monitor.wait_for(MonitorEvent.CAPTURE)
            #ctx.release(request_driver, request_backpressure_driver, request_monitor, response_driver, response_monitor, response_backpressure_driver)



@forastero.sequence()
@forastero.requires("request_driver", MappedRequestInitiator)
@forastero.requires("request_backpressure_driver", obi.ObiRequestBackpressureDriver)
@forastero.requires("request_monitor", obi.ObiRequestMonitor)
@forastero.requires("response_driver", obi.ObiResponseDriver)
@forastero.requires("response_backpressure_driver", mapped.MappedResponseResponder)
@forastero.requires("response_monitor", MappedResponseMonitor)
async def random_read_seq_bp(
    ctx: SeqContext,
    request_driver: MappedRequestInitiator,
    request_backpressure_driver: obi.ObiRequestBackpressureDriver,
    request_monitor: obi.ObiRequestMonitor,
    response_driver: obi.ObiResponseDriver,
    response_backpressure_driver: mapped.MappedResponseResponder,
    response_monitor: MappedResponseMonitor,
    backpressure_func: partial,
    count: int,
    tb: ObiXbarTB,
    addresses: list[int] | None = None
) -> None:
    for i in range(count):
        addr = addresses[ctx.random.randrange(0, len(addresses))]
        async with ctx.lock(request_driver, request_backpressure_driver, request_monitor, response_driver, response_monitor, response_backpressure_driver):
            request_driver.enqueue(
                MappedRequest(
                    cycles=tb.master_delay_func(tb),
                    ident=i+1,
                    address=addr,
                    mode=MappedAccess.READ
                )
            )
            """
            request_backpressure_driver.enqueue(# Drives agnt low for the specified duration of cycles
                obi.ObiBackpressure(
                    ready=0,
                    cycles=backpressure_func(tb)
                ) 
            )
            request_backpressure_driver.enqueue(# Drives agnt high for 1 cycle to complete the transaction
                obi.ObiBackpressure(
                    ready=1,
                    cycles=1
                ),
                DriverEvent.POST_DRIVE
            )
            """
            await request_monitor.wait_for(MonitorEvent.CAPTURE)


@forastero.sequence()
@forastero.requires("request_driver", MappedRequestInitiator)
@forastero.requires("request_backpressure_driver", obi.ObiRequestBackpressureDriver)
@forastero.requires("request_monitor", obi.ObiRequestMonitor)
@forastero.requires("response_driver", obi.ObiResponseDriver)
@forastero.requires("response_backpressure_driver", mapped.MappedResponseResponder)
@forastero.requires("response_monitor", MappedResponseMonitor)
async def random_write_seq(
    ctx: SeqContext,
    request_driver: MappedRequestInitiator,
    request_backpressure_driver: obi.ObiRequestBackpressureDriver,
    request_monitor: obi.ObiRequestMonitor,
    response_driver: obi.ObiResponseDriver,
    response_backpressure_driver: mapped.MappedResponseResponder,
    response_monitor: MappedResponseMonitor,
    backpressure_func: partial,
    count: int,
    tb: ObiXbarTB,
    addresses: list[int] | None = None,
    data: list[int] | None = None,
    strobe: list[int] | None = None,
) -> None:
    for i in range(count):
        addr = addresses[ctx.random.randrange(0, len(addresses))]
        value = data[ctx.random.randrange(0, len(data))]
        strb = strobe[ctx.random.randrange(0, len(strobe))]
        async with ctx.lock(request_driver, request_backpressure_driver, request_monitor, response_driver, response_monitor, response_backpressure_driver):
            request_driver.enqueue(
                MappedRequest(
                    cycles=tb.master_delay_func(tb),
                    ident=i+1,
                    address=addr,
                    mode=MappedAccess.WRITE,
                    data=value,
                    strobe=strb
                )
            )
            """
            request_backpressure_driver.enqueue(# Drives agnt low for the specified duration of cycles
                obi.ObiBackpressure(
                    ready=0,
                    cycles=backpressure_func(tb)
                ) 
            )
            request_backpressure_driver.enqueue(# Drives agnt high for 1 cycle to complete the transaction
                obi.ObiBackpressure(
                    ready=1,
                    cycles=1
                ),
                DriverEvent.POST_DRIVE
            )
            """
            await request_monitor.wait_for(MonitorEvent.CAPTURE)




    






# ---------- TEST CASES ----------

@ObiXbarTB.testcase()
@ObiXbarTB.parameter("repeat", int, 10)
async def ifu_linear_read_test(
    tb: ObiXbarTB,
    log,
    repeat
):  
    log.info(msg=f"Test started")
    test_mem = gen_memory_data(int("0000_0000", 16), range(1, repeat+1))
    tb.mmio_device.flash(test_mem)
    address_sequence = tb.gen_linear_address_seq(int("0000_0000", 16), range(0, (repeat*4), 4))
    log.info(msg=f"Schedueling IFU linear read sequence")
    tb.schedule(
        linear_read_seq(
            driver=tb.ifu_mapped_request_driver,
            tb=tb,
            addresses=address_sequence
        )
    )

@ObiXbarTB.testcase()
@ObiXbarTB.parameter("repeat", int, 10)
@ObiXbarTB.parameter("start_address", int, int("4000_0000", 16))
async def lsu_linear_read_test(
    tb: ObiXbarTB,
    log,
    repeat,
    start_address
):  
    log.info(msg=f"Test started")
    test_mem = gen_memory_data(start_address, range(1, repeat+1))
    tb.mmio_device.flash(test_mem)
    address_sequence = tb.gen_linear_address_seq(start_address, range(0, (repeat*4), 4))
    log.info(msg='{:032b}'.format(start_address))
    log.info(msg=f"Schedueling LSU linear read sequence")
    tb.schedule(
        linear_read_seq(
            driver=tb.lsu_mapped_request_driver,
            tb=tb,
            addresses=address_sequence
        )
    )



@ObiXbarTB.testcase(timeout=8000)
@ObiXbarTB.parameter("repeat", int, 100)
@ObiXbarTB.parameter("start_address_s1", int, int("0000_0000", 16))
@ObiXbarTB.parameter("start_address_s2", int, int("4000_0000", 16))
async def lsu_linear_read_all_test(
    tb: ObiXbarTB,
    log,
    repeat,
    start_address_s1,
    start_address_s2
):  
    log.info(msg=f"Test started")

    tb.lsu_response_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,5))
    tb.s1_request_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(3,4))
    tb.s2_request_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,2))
    tb.slave_delay_func = partial(ObiXbarTB.random_backpressure , data=range(4,6))
    tb.master_delay_func = partial(ObiXbarTB.random_backpressure, data=range(2,5))

    test_mem = gen_memory_data(start_address_s1, range(8, 8+repeat+1))
    test_mem.update(gen_memory_data(start_address_s2, range(1, repeat+1)))
    tb.mmio_device.flash(test_mem)
    log.info(msg=tb.mmio_device)
    address_sequence_s1 = tb.gen_linear_address_seq(start_address_s1, range(0, (repeat*4), 4))
    address_sequence_s2 = tb.gen_linear_address_seq(start_address_s2, range(0, (repeat*4), 4))
    #log.info(msg='{:032b}'.format(start_address))
    log.info(msg=f"Schedueling LSU linear read all sequence")
    s1 = tb.schedule(
        linear_read_seq_bp(
            request_driver=tb.lsu_mapped_request_driver,
            request_backpressure_driver=tb.s1_obi_request_backpressure_driver,
            request_monitor=tb.s1_obi_request_monitor,
            response_driver=tb.s1_obi_response_driver,
            response_backpressure_driver=tb.lsu_mapped_response_backpressure_driver,
            response_monitor=tb.lsu_mapped_response_monitor,
            backpressure_func=tb.s1_request_backpressure_func,
            tb=tb,
            addresses=address_sequence_s1
        )
    )
    s2 = tb.schedule(
        linear_read_seq_bp(
            request_driver=tb.lsu_mapped_request_driver,
            request_backpressure_driver=tb.s2_obi_request_backpressure_driver,
            request_monitor=tb.s2_obi_request_monitor,
            response_driver=tb.s2_obi_response_driver,
            response_backpressure_driver=tb.lsu_mapped_response_backpressure_driver,
            response_monitor=tb.lsu_mapped_response_monitor,
            backpressure_func=tb.s2_request_backpressure_func,
            tb=tb,
            addresses=address_sequence_s2
        )
    )

    await s1
    await s2



@ObiXbarTB.testcase(timeout=8000)
@ObiXbarTB.parameter("repeat", int, 100)
@ObiXbarTB.parameter("start_address_s1", int, int("0000_0000", 16))
@ObiXbarTB.parameter("start_address_s2", int, int("4000_0000", 16))
async def lsu_random_read_all_test(
    tb: ObiXbarTB,
    log,
    repeat,
    start_address_s1,
    start_address_s2
):  
    log.info(msg=f"Test started")

    tb.lsu_response_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,5))
    tb.s1_request_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(3,4))
    tb.s2_request_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,2))
    tb.slave_delay_func = partial(ObiXbarTB.random_backpressure , data=range(4,6))
    tb.master_delay_func = partial(ObiXbarTB.random_backpressure, data=range(2,5))

    test_mem = gen_memory_data(start_address_s1, range(8, 8+repeat+1))
    test_mem.update(gen_memory_data(start_address_s2, range(1, repeat+1)))
    tb.mmio_device.flash(test_mem)
    log.info(msg=tb.mmio_device)
    address_sequence_s1 = tb.gen_linear_address_seq(start_address_s1, range(0, (repeat*4), 4)) # change to gen random addresses, this is still ok as it gets random picked but better if this was random too  
    address_sequence_s2 = tb.gen_linear_address_seq(start_address_s2, range(0, (repeat*4), 4))
    #log.info(msg='{:032b}'.format(start_address))
    log.info(msg=f"Schedueling LSU linear read all sequence")
    s1 = tb.schedule(
        random_read_seq_bp(
            request_driver=tb.lsu_mapped_request_driver,
            request_backpressure_driver=tb.s1_obi_request_backpressure_driver,
            request_monitor=tb.s1_obi_request_monitor,
            response_driver=tb.s1_obi_response_driver,
            response_backpressure_driver=tb.lsu_mapped_response_backpressure_driver,
            response_monitor=tb.lsu_mapped_response_monitor,
            backpressure_func=tb.s1_request_backpressure_func,
            count=repeat,
            tb=tb,
            addresses=address_sequence_s1
        )
    )
    s2 = tb.schedule(
        random_read_seq_bp(
            request_driver=tb.lsu_mapped_request_driver,
            request_backpressure_driver=tb.s2_obi_request_backpressure_driver,
            request_monitor=tb.s2_obi_request_monitor,
            response_driver=tb.s2_obi_response_driver,
            response_backpressure_driver=tb.lsu_mapped_response_backpressure_driver,
            response_monitor=tb.lsu_mapped_response_monitor,
            backpressure_func=tb.s2_request_backpressure_func,
            count=repeat,
            tb=tb,
            addresses=address_sequence_s2
        )
    )

    await s1
    await s2




@ObiXbarTB.testcase(timeout=8000)
@ObiXbarTB.parameter("repeat", int, 100)
@ObiXbarTB.parameter("start_address_s1", int, int("0000_0000", 16))
@ObiXbarTB.parameter("start_address_s2", int, int("4000_0000", 16))
async def lsu_random_write_all_test(
    tb: ObiXbarTB,
    log,
    repeat,
    start_address_s1,
    start_address_s2
):  
    log.info(msg=f"Test started")

    tb.lsu_response_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,5))
    tb.s1_request_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(3,4))
    tb.s2_request_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,2))
    tb.slave_delay_func = partial(ObiXbarTB.random_backpressure , data=range(4,6))
    tb.master_delay_func = partial(ObiXbarTB.random_backpressure, data=range(2,5))

    test_mem = gen_memory_data(start_address_s1, range(8, 8+repeat+1))
    test_mem.update(gen_memory_data(start_address_s2, range(1, repeat+1)))
    tb.mmio_device.flash(test_mem)
    log.info(msg=tb.mmio_device)
    address_sequence_s1 = tb.gen_linear_address_seq(start_address_s1, range(0, (repeat*4), 4)) # change to gen random addresses, this is still ok as it gets random picked but better if this was random too  
    address_sequence_s2 = tb.gen_linear_address_seq(start_address_s2, range(0, (repeat*4), 4))


    rnd_data_s1 = tb.gen_random_data_seq(repeat, tb.seed)
    rnd_strb_s1 = tb.gen_random_strobe_seq(repeat, tb.seed)

    rnd_data_s2 = tb.gen_random_data_seq(repeat, tb.seed)
    rnd_strb_s2 = tb.gen_random_strobe_seq(repeat, tb.seed)

    #log.info(msg='{:032b}'.format(start_address))
    log.info(msg=f"Schedueling LSU linear read all sequence")
    s1 = tb.schedule(
        random_write_seq(
            request_driver=tb.lsu_mapped_request_driver,
            request_backpressure_driver=tb.s1_obi_request_backpressure_driver,
            request_monitor=tb.s1_obi_request_monitor,
            response_driver=tb.s1_obi_response_driver,
            response_backpressure_driver=tb.lsu_mapped_response_backpressure_driver,
            response_monitor=tb.lsu_mapped_response_monitor,
            backpressure_func=tb.s1_request_backpressure_func,
            count=repeat,
            tb=tb,
            addresses=address_sequence_s1,
            data=rnd_data_s1,
            strobe=rnd_strb_s1
        )
    )
    s2 = tb.schedule(
        random_write_seq(
            request_driver=tb.lsu_mapped_request_driver,
            request_backpressure_driver=tb.s2_obi_request_backpressure_driver,
            request_monitor=tb.s2_obi_request_monitor,
            response_driver=tb.s2_obi_response_driver,
            response_backpressure_driver=tb.lsu_mapped_response_backpressure_driver,
            response_monitor=tb.lsu_mapped_response_monitor,
            backpressure_func=tb.s2_request_backpressure_func,
            count=repeat,
            tb=tb,
            addresses=address_sequence_s2,
            data=rnd_data_s2,
            strobe=rnd_strb_s2
        )
    )

    await s1
    await s2




@ObiXbarTB.testcase(timeout=800000)
@ObiXbarTB.parameter("repeat", int, 50)
@ObiXbarTB.parameter("start_address_s1", int, int("0000_0000", 16))
@ObiXbarTB.parameter("start_address_s2", int, int("4000_0000", 16))
async def lsu_random_read_write_all_test(
    tb: ObiXbarTB,
    log,
    repeat,
    start_address_s1,
    start_address_s2
):  
    log.info(msg=f"Test started")

    tb.lsu_response_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,20))
    tb.s1_request_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(5,15))
    tb.s2_request_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(2,10))
    tb.slave_delay_func = partial(ObiXbarTB.random_backpressure , data=range(1,7))
    tb.master_delay_func = partial(ObiXbarTB.random_backpressure, data=range(6,17))

    test_mem = gen_memory_data(start_address_s1, range(8, 8+repeat+1))
    test_mem.update(gen_memory_data(start_address_s2, range(1, repeat+1)))
    tb.mmio_device.flash(test_mem)
    log.info(msg=tb.mmio_device)
    address_sequence_s1 = tb.gen_linear_address_seq(start_address_s1, range(0, (repeat*4), 4)) # change to gen random addresses, this is still ok as it gets random picked but better if this was random too  
    address_sequence_s2 = tb.gen_linear_address_seq(start_address_s2, range(0, (repeat*4), 4))


    rnd_data_s1 = tb.gen_random_data_seq(repeat, tb.seed)
    rnd_strb_s1 = tb.gen_random_strobe_seq(repeat, tb.seed)

    rnd_data_s2 = tb.gen_random_data_seq(repeat, tb.seed)
    rnd_strb_s2 = tb.gen_random_strobe_seq(repeat, tb.seed)

    #log.info(msg='{:032b}'.format(start_address))
    log.info(msg=f"Schedueling LSU linear read all sequence")
    s1_w = tb.schedule(
        random_write_seq(
            request_driver=tb.lsu_mapped_request_driver,
            request_backpressure_driver=tb.s1_obi_request_backpressure_driver,
            request_monitor=tb.s1_obi_request_monitor,
            response_driver=tb.s1_obi_response_driver,
            response_backpressure_driver=tb.lsu_mapped_response_backpressure_driver,
            response_monitor=tb.lsu_mapped_response_monitor,
            backpressure_func=tb.s1_request_backpressure_func,
            count=repeat,
            tb=tb,
            addresses=address_sequence_s1,
            data=rnd_data_s1,
            strobe=rnd_strb_s1
        )
    )
    s2_w = tb.schedule(
        random_write_seq(
            request_driver=tb.lsu_mapped_request_driver,
            request_backpressure_driver=tb.s2_obi_request_backpressure_driver,
            request_monitor=tb.s2_obi_request_monitor,
            response_driver=tb.s2_obi_response_driver,
            response_backpressure_driver=tb.lsu_mapped_response_backpressure_driver,
            response_monitor=tb.lsu_mapped_response_monitor,
            backpressure_func=tb.s2_request_backpressure_func,
            count=repeat,
            tb=tb,
            addresses=address_sequence_s2,
            data=rnd_data_s2,
            strobe=rnd_strb_s2
        )
    )
    s1_r = tb.schedule(
        random_read_seq_bp(
            request_driver=tb.lsu_mapped_request_driver,
            request_backpressure_driver=tb.s1_obi_request_backpressure_driver,
            request_monitor=tb.s1_obi_request_monitor,
            response_driver=tb.s1_obi_response_driver,
            response_backpressure_driver=tb.lsu_mapped_response_backpressure_driver,
            response_monitor=tb.lsu_mapped_response_monitor,
            backpressure_func=tb.s1_request_backpressure_func,
            count=repeat,
            tb=tb,
            addresses=address_sequence_s1
        )
    )
    s2_r = tb.schedule(
        random_read_seq_bp(
            request_driver=tb.lsu_mapped_request_driver,
            request_backpressure_driver=tb.s2_obi_request_backpressure_driver,
            request_monitor=tb.s2_obi_request_monitor,
            response_driver=tb.s2_obi_response_driver,
            response_backpressure_driver=tb.lsu_mapped_response_backpressure_driver,
            response_monitor=tb.lsu_mapped_response_monitor,
            backpressure_func=tb.s2_request_backpressure_func,
            count=repeat,
            tb=tb,
            addresses=address_sequence_s2
        )
    )

    await s1_w
    await s2_w
    await s1_r
    await s2_r



if __name__ == "__main__":
    sys.path.insert(0, '/foss/designs/rvj1-SoC/soc_tb_lib')
    test_obi_crossbar_runner()