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
    runner = get_test_runner("obi_xbar_testing_param_module")
    runner.test(hdl_toplevel="obi_xbar_testing_param_module",test_module = "test_obi_crossbar", waves=WAVES)

class MappedResponseMonitor(BaseMonitor):
    async def monitor(self, capture):
        while True:
            await RisingEdge(self.clk)
            if self.rst.value == 0:
                await RisingEdge(self.clk)
                continue
            if self.io.get("valid") and self.io.get("ready"):
                tran = MappedResponse(
                    #ident=self.io.get("id", 0),
                    data=self.io.get("data", 0),
                    error=self.io.get("error", 0),
                )
                capture(tran)

BaseIO.DEFAULT_IO_STYLE = io_suffix_style

class ObiXbarTB(BaseBench):
    def __init__(self, dut):
        super().__init__(dut, clk=dut.clk_i, rst=dut.rstn_i, rst_active_high=False)

        self.subordinates = 2
        self.fifo_width = 1024
        self.id_width = math.log2(self.fifo_width * self.subordinates) +1 

        self.mmio_device = Memory_device(self)

        self.ifu_response_backpressure_func = partial(ObiXbarTB.const_backpressure, cycles=0)
        self.lsu_response_backpressure_func = partial(ObiXbarTB.const_backpressure, cycles=0)
        self.m2_response_backpressure_func = partial(ObiXbarTB.const_backpressure, cycles=0)

        self.s0_request_backpressure_func = partial(ObiXbarTB.const_backpressure, cycles=0)
        self.s1_request_backpressure_func = partial(ObiXbarTB.const_backpressure, cycles=0)
        #self.s2_request_backpressure_func = partial(ObiXbarTB.const_backpressure, cycles=0)

        self.master_delay_func = partial(ObiXbarTB.const_backpressure, cycles=0)
        self.slave_delay_func = partial(ObiXbarTB.const_backpressure, cycles=0)

        self.response_window =2048
        self.request_window = 2048
    # ---------- IO ----------

        # IFU MAPPED io
        mapped_request_ifu_io = mapped.MappedRequestIO(dut, "ifu_req", IORole.RESPONDER) # Init io IFU->M0 as driver is MAPPED request driver
        mapped_response_ifu_io = mapped.MappedResponseIO(dut, "ifu_rsp", IORole.INITIATOR) # Rsp io IFU<-M0 as MAPPED monitor is on IFU

        # LSU MAPPED io
        mapped_request_lsu_io = mapped.MappedRequestIO(dut, "lsu_req", IORole.RESPONDER) # Init io LSU->M1 as driver is MAPPED request driver
        mapped_response_lsu_io = mapped.MappedResponseIO(dut, "lsu_rsp", IORole.INITIATOR) # Rsp io LSU<-M1 as MAPPED monitor is on LSU

        # M2 MAPPED io
        mapped_request_m2_io = mapped.MappedRequestIO(dut, "m2_req", IORole.RESPONDER) 
        mapped_response_m2_io = mapped.MappedResponseIO(dut, "m2_rsp", IORole.INITIATOR) 

        # S0 OBI io
        s0_obi_request_io = obi.ObiRequestIO(dut, "s0_obi", IORole.INITIATOR ) # Rsp io Mi->S0 as OBI monitor is on S0 
        s0_obi_response_io = obi.ObiResponseIO(dut, "s0_obi", IORole.RESPONDER) # Init io Mi<-S0 as driver is OBI response driver

        # S1 OBI io
        s1_obi_request_io = obi.ObiRequestIO(dut, "s1_obi", IORole.INITIATOR ) # Rsp io Mi->S1 as OBI monitor is on S1 
        s1_obi_response_io = obi.ObiResponseIO(dut, "s1_obi", IORole.RESPONDER) # Init io Mi<-S1 as driver is OBI response driver

    # ---------- Drivers ----------

        # IFU MAPPED request channel drivers 

        self.register(  # MAPPED IFU->M0 request signals driver
            "ifu_mapped_request_driver",
            mapped.MappedRequestInitiator(self, mapped_request_ifu_io, self.clk, self.rst, name="ifu")
        )
        self.ifu_mapped_request_driver.subscribe(DriverEvent.ENQUEUE, self.push_request_reference)
        self.ifu_mapped_request_driver.subscribe(DriverEvent.PRE_DRIVE, self.drive_request_backpressure)

        # IFU MAPPED response channel drivers

        self.register(  # MAPPED IFU->M0 response backpressure signal driver
            "ifu_mapped_response_backpressure_driver",
            mapped.MappedResponseResponder(self, mapped_response_ifu_io, self.clk, self.rst, name="ifu")
        )

        # LSU MAPPED request channel drivers

        self.register(  # MAPPED LSU->M1 request signal driver
            "lsu_mapped_request_driver",
            mapped.MappedRequestInitiator(self, mapped_request_lsu_io, self.clk, self.rst, name="lsu")
        )
        self.lsu_mapped_request_driver.subscribe(DriverEvent.ENQUEUE, self.push_request_reference)
        self.lsu_mapped_request_driver.subscribe(DriverEvent.PRE_DRIVE, self.drive_request_backpressure)

        # LSU MAPPED response channel drivers

        self.register(  # MAPPED LSU->M1 response backpressure signal driver
            "lsu_mapped_response_backpressure_driver",
            mapped.MappedResponseResponder(self, mapped_response_lsu_io, self.clk, self.rst, name="lsu")
        )

        # M2 MAPPED request channel drivers

        self.register(  
            "m2_mapped_request_driver",
            mapped.MappedRequestInitiator(self, mapped_request_m2_io, self.clk, self.rst, name="m2")
        )
        self.m2_mapped_request_driver.subscribe(DriverEvent.ENQUEUE, self.push_request_reference)
        self.m2_mapped_request_driver.subscribe(DriverEvent.PRE_DRIVE, self.drive_request_backpressure)

        # M2 MAPPED response channel drivers

        self.register(  # MAPPED LSU->M2 response backpressure signal driver
            "m2_mapped_response_backpressure_driver",
            mapped.MappedResponseResponder(self, mapped_response_m2_io, self.clk, self.rst, name="m2")
        )

        # S0 OBI request channel drivers

        self.register(  # OBI Mi<-S0 request backpressure signal driver
            "s0_obi_request_backpressure_driver",
            obi.ObiRequestBackpressureDriver(self, s0_obi_request_io, self.clk, self.rst, name="s0")
        )

        # S0 OBI response channel drivers

        self.register( # OBI Mi<-S0 response signal driver
            "s0_obi_response_driver",
            obi.ObiResponseDriver(self, s0_obi_response_io, self.clk, self.rst, name="s0")
        )
        self.s0_obi_response_driver.subscribe(DriverEvent.PRE_DRIVE, self.drive_response_backpressure)
        self.s0_obi_response_driver.subscribe(DriverEvent.ENQUEUE, self.push_response_reference)

        # S1 OBI request channel drivers

        self.register(  # OBI Mi<-S1 request backpressure signal driver
            "s1_obi_request_backpressure_driver",
            obi.ObiRequestBackpressureDriver(self, s1_obi_request_io, self.clk, self.rst, name="s1")
        )

        # S1 OBI response channel drivers

        self.register( # OBI Mi<-S1 response signal driver
            "s1_obi_response_driver",
            obi.ObiResponseDriver(self, s1_obi_response_io, self.clk, self.rst, name="s1")
        )
        self.s1_obi_response_driver.subscribe(DriverEvent.PRE_DRIVE, self.drive_response_backpressure)
        self.s1_obi_response_driver.subscribe(DriverEvent.ENQUEUE, self.push_response_reference)


    # ---------- Monitors ----------
        
        # IFU monitor
        
        self.register(  # MAPPED monitor (monitor)<IFU<-M0 for reading response channel signals
            "ifu_mapped_response_monitor",
            MappedResponseMonitor(self, mapped_response_ifu_io, self.clk, self.rst, name="ifu"),
            sb_match_window=self.response_window,
            sb_drain_policy=forastero.DrainPolicy.MON_AND_REF
        )
        

        # LSU monitor
        
        self.register(  # MAPPED monitor (monitor)<LSU<-M1 for reading response channel signals
            "lsu_mapped_response_monitor",
            MappedResponseMonitor(self, mapped_response_lsu_io, self.clk, self.rst, name="lsu"),
            sb_match_window=self.response_window,
            sb_drain_policy=forastero.DrainPolicy.MON_AND_REF
        )

        # M2 monitor

        self.register(  
            "m2_mapped_response_monitor",
            MappedResponseMonitor(self, mapped_response_m2_io, self.clk, self.rst, name="m2"),
            sb_match_window=self.response_window,
            sb_drain_policy=forastero.DrainPolicy.MON_AND_REF
        )
        
        

        # S0 monitor
        self.register(  # OBI monitor Mi->S0>(monitor) for reading request channel signals
            "s0_obi_request_monitor",
            obi.ObiRequestMonitor(self, s0_obi_request_io, self.clk, self.rst, name="s0"), 
            sb_match_window=self.request_window,
            sb_queues=("ifu", "lsu"),
            sb_filter=self.filter,
            sb_drain_policy=forastero.DrainPolicy.MON_AND_REF
        )
        self.s0_obi_request_monitor.subscribe(MonitorEvent.CAPTURE, self.drive_response)

        # S1 monitor
        self.register(  # OBI monitor Mi->S1>(monitor) for reading request channel signals
            "s1_obi_request_monitor",
            obi.ObiRequestMonitor(self, s1_obi_request_io, self.clk, self.rst, name="s1"),
            sb_match_window=self.request_window,
            sb_queues=("ifu", "lsu", "m2"),
            sb_filter=self.filter,
            sb_drain_policy=forastero.DrainPolicy.MON_AND_REF
        )
        self.s1_obi_request_monitor.subscribe(MonitorEvent.CAPTURE, self.drive_response)


# ---------- Subscriber methods ----------

    # Monitor reference push methods

    def push_request_reference( # Pushes the request transaction signals reference from request driver input to the request monitor for comparison
        self, driver:mapped.MappedRequestInitiator, event:DriverEvent , obj:mapped.MappedRequest
    ):
        monitor = ("s" + self.request_decode(obj.address)  + "_obi_request_monitor")
        self.scoreboard.channels[monitor].push_reference( 
            driver.name[0:driver.name.find("_")],
            obi.ObiRequest(   # Transaction signals to push and compare 
                obi_aadr=obj.address,
                obi_awe=(obj.mode - 1), # mapped READ value is 1 where obi READ is 0 (diffrence in the way classes were written)
                obi_abe=obj.strobe,
                obi_awdata=obj.data,
                #obi_aid=obj.ident,    
                obi_mid=self.response_encode(driver.name[0:driver.name.find("_")])  
            )
        )

    
    def push_response_reference(    # Pushes the response transaction signals reference from response driver input to the response monitor for comparison
        self, driver:obi.ObiResponseDriver, event:DriverEvent, obj:obi.ObiResponse
    ):
        manager = self.response_decode(obj.obi_mid)
        monitor = manager + "_mapped_response_monitor"
        self.log.info("Pushing reference to " + monitor + " with mid: " + str(obj.obi_mid))
        self.scoreboard.channels[monitor].push_reference(
            mapped.MappedResponse(  # Transaction signals to push and compare
                #ident=0,
                data=obj.obi_rdata,
                error=obj.obi_rerr,
                valid=True
            )
        )


    # Response driver drive methods

    def drive_response( # Drives the response transaction upon the monitor capture of the request transaction
            self, monitor:obi.ObiRequestMonitor, event:MonitorEvent, obj:obi.ObiRequest
    ):  
        driver_name = getattr(self, monitor.name[0:monitor.name.find("_")] + "_obi_response_driver" )
        self.log.info(msg=f"Captured request transaction on slave")
        match obj.obi_awe: # Check if request was a READ or WRITE transaction
            case obi.ObiAccess.READ:  # On READ, read data from address in mmio device
                read = self.mmio_device.read(obj.obi_aadr)
                err = 1 if read is None else 0
                driver_name.enqueue(# Drive the read response transaction signals (data, error) 
                    obi.ObiResponse(
                        valid_delay=self.slave_delay_func(self),
                        obi_rdata = read,
                        obi_rerr=err,
                        #obi_rid=obj.obi_aid,
                        obi_mid=obj.obi_mid
                    )
                )
                self.log.info(msg=f"Driving READ response on s0")
            case obi.ObiAccess.WRITE: # On WRITE, write the data to address in mmio device
                err = self.mmio_device.write(obj.obi_aadr, obj.obi_awdata, obj.obi_abe)
                driver_name.enqueue(# Drive the write response transaction signals (error)
                    obi.ObiResponse(
                        valid_delay=self.slave_delay_func(self),
                        obi_rdata = 0,
                        obi_rerr=err,
                        #obi_rid=obj.obi_aid,
                        obi_mid=obj.obi_mid
                    )
                )
                self.log.info(msg=f"Driving WRITE response on s0")

    """
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
    """

    """         
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
    
    """            

    # Backpressure drivers drive methods
     
    def drive_response_backpressure( # Drives the ready signal 
            self, driver:obi.ObiResponseDriver, event:DriverEvent , obj:obi.ObiResponse
    ):
        driver_name = getattr(self, self.response_decode(obj.obi_mid) + "_mapped_response_backpressure_driver")
        bp_func = getattr(self, self.response_decode(obj.obi_mid) + "_response_backpressure_func")(self)
        driver_name.enqueue(# Drives ready low for the specified duration of cycles
            mapped.MappedBackpressure(
                ready=0,
                cycles=bp_func
            ) 
        )
        driver_name.enqueue(# Drives ready high for 1 cycle to complete the transaction
            mapped.MappedBackpressure(
                ready=1,
                cycles=1
            )
        )

    """
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
    """
        
    def drive_request_backpressure( # Drives the agnt signal
            self, driver:mapped.MappedRequestInitiator, event:DriverEvent , obj:mapped.MappedRequest
    ):
        driver_name = getattr(self, "s" + self.request_decode(obj.address) + "_obi_request_backpressure_driver")
        bp_func = getattr(self, "s" + self.request_decode(obj.address) + "_request_backpressure_func")(self)
        self.log.info("Driving backpressure on: " + "s" + self.request_decode(obj.address) + "_obi_request_backpressure_driver")
        driver_name.enqueue(# Drives agnt low for the specified duration of cycles
            obi.ObiBackpressure(
                ready=0,
                cycles=bp_func
            ) 
        )
        driver_name.enqueue(# Drives agnt high for 1 cycle to complete the transaction
            obi.ObiBackpressure(
                ready=1,
                cycles=1
            )
        )

    """
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

    """

# ---------- Monitor Filters ----------

    def filter(self, monitor: obi.ObiRequestMonitor, event: MonitorEvent, obj: obi.ObiRequest) -> obi.ObiRequest | None:
        self.log.info(obj)
        for queue in self.scoreboard.channels[monitor.name]._q_ref.values():
            if queue.level > 0:
                ref = queue.peek()
                self.log.info(ref)
                if ref == obj:
                    self.log.info("match found, mid: " + str(ref.obi_mid))
                    obj.obi_mid = ref.obi_mid
        return obj


# ---------- Decoder methods ----------

    def request_decode(self, address: int) -> str:
        decode_dict = {
            (int("0000_0000", 16), int("4000_0000", 16)) : "0",
            (int("4000_0000", 16), int("4000_0000", 16)) : "1"
        }
        for base, mask in list(decode_dict.keys()):
            if ((base & mask) == (address & mask) ):
                slave_id = decode_dict[(base, mask)]
        return slave_id
    
    def response_encode(self, mid: int) -> str:
        decode_dict  = {
            "ifu" : 0,
            "lsu" : 1,
            "m2" : 2
        }
        return decode_dict[mid]
    
    def response_decode(self, mid: int) -> str:
        decode_dict  = {
            0: "ifu",
            1: "lsu",
            2: "m2"
        }
        return decode_dict[mid]
    
    """"
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
    """

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
                    ident=(i%(int(math.pow(2, tb.id_width)-1)))+1, # mod (ID_WIDTH-1),
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
#@forastero.requires("response_monitor", MappedResponseMonitor)
async def linear_read_seq_bp(
    ctx: SeqContext,
    request_driver: MappedRequestInitiator,
    request_backpressure_driver: obi.ObiRequestBackpressureDriver,
    request_monitor: obi.ObiRequestMonitor,
    response_driver: obi.ObiResponseDriver,
    response_backpressure_driver: mapped.MappedResponseResponder,
    strb: int,
    #response_monitor: MappedResponseMonitor,
    #backpressure_func: partial,
    tb: ObiXbarTB,
    addresses: list[int] | None = None,
) -> None:
    for i, addr in enumerate(addresses):
        async with ctx.lock(request_driver):
            request_driver.enqueue(
                MappedRequest(
                    cycles=tb.master_delay_func(tb),
                    ident=(i%(int(math.pow(2, tb.id_width)-1)))+1, # mod (ID_WIDTH-1)
                    address=addr,
                    mode=MappedAccess.READ,
                    strobe=strb
                )
            )
            #await request_monitor.wait_for(MonitorEvent.CAPTURE)
        
        
        """
        async with ctx.lock(request_monitor):
            await request_monitor.wait_for(MonitorEvent.CAPTURE)

        
        async with ctx.lock(response_driver, request_backpressure_driver):
            response_driver.wait_for(DriverEvent.POST_DRIVE)
            request_backpressure_driver.wait_for(DriverEvent.POST_DRIVE)
        

            
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
            #await request_monitor.wait_for(MonitorEvent.CAPTURE)
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
    strb: int,
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
                    ident=(i%(int(math.pow(2, tb.id_width)-1)))+1, # mod (ID_WIDTH-1),
                    address=addr,
                    mode=MappedAccess.READ,
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
                    ident=(i%(int(math.pow(2, tb.id_width)-1)))+1, # mod (ID_WIDTH-1),
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
async def ifu_linear_read_test1_0(
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
@ObiXbarTB.parameter("start_address", int, int("0000_0000", 16))
async def lsu_linear_read_test1_1(
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

@ObiXbarTB.testcase()
@ObiXbarTB.parameter("repeat", int, 10)
@ObiXbarTB.parameter("start_address", int, int("0000_0000", 16))
async def ifu_lsu_linear_read_test2_0(
    tb: ObiXbarTB,
    log,
    repeat,
    start_address
): 
    test_mem = gen_memory_data(start_address, range(1, repeat+1))
    tb.mmio_device.flash(test_mem)
    address_sequence = tb.gen_linear_address_seq(start_address, range(0, (repeat*4), 4))
    m0 = tb.schedule(
        linear_read_seq(
            driver=tb.ifu_mapped_request_driver,
            tb=tb,
            addresses=address_sequence
        )
    )
    m1 = tb.schedule(
        linear_read_seq(
            driver=tb.lsu_mapped_request_driver,
            tb=tb,
            addresses=address_sequence
        )
    )

    await m0,m1

@ObiXbarTB.testcase(timeout=80000)
@ObiXbarTB.parameter("repeat", int, 10*1)
@ObiXbarTB.parameter("start_address", int, int("0000_0000", 16))
async def ifu_lsu_linear_read_bp_test2_1(
    tb: ObiXbarTB,
    log,
    repeat,
    start_address
): 
    test_mem = gen_memory_data(start_address, range(1, (repeat+1)))
    tb.mmio_device.flash(test_mem)
    address_sequence = tb.gen_linear_address_seq(start_address, range(0, (repeat*4), 4))
    #adr2 = tb.gen_linear_address_seq(start_address, range(20, (repeat*4)*2, 4))

    
    tb.ifu_response_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,1))
    tb.lsu_response_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,1))

    tb.s0_request_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,2))
        

    tb.master_delay_func = partial(ObiXbarTB.random_backpressure, data=range(0,1))
    tb.slave_delay_func = partial(ObiXbarTB.random_backpressure, data=range(0,1))
    
    m0 = tb.schedule(
        linear_read_seq_bp(
            request_driver=tb.ifu_mapped_request_driver,
            request_backpressure_driver=tb.s0_obi_request_backpressure_driver,
            request_monitor=tb.s0_obi_request_monitor,
            response_driver=tb.s0_obi_response_driver,
            response_backpressure_driver=tb.ifu_mapped_response_backpressure_driver,
            strb=0,
            tb=tb,
            addresses=address_sequence
        )
    )
    m1 = tb.schedule(
        linear_read_seq_bp(
            request_driver=tb.lsu_mapped_request_driver,
            request_backpressure_driver=tb.s0_obi_request_backpressure_driver,
            request_monitor=tb.s0_obi_request_monitor,
            response_driver=tb.s0_obi_response_driver,
            response_backpressure_driver=tb.lsu_mapped_response_backpressure_driver,
            strb=1,
            tb=tb,
            addresses=address_sequence
        )
    )

    await m0,m1



@ObiXbarTB.testcase(timeout=8000000)
@ObiXbarTB.parameter("repeat", int, 100*30)
@ObiXbarTB.parameter("start_address", int, int("4000_0000", 16))
async def ifu_lsu_m2_linear_read_bp_test3_0(
    tb: ObiXbarTB,
    log,
    repeat,
    start_address
): 
    test_mem = gen_memory_data(start_address, range(1, (repeat+1)))
    tb.mmio_device.flash(test_mem)
    address_sequence = tb.gen_linear_address_seq(start_address, range(0, (repeat*4), 4))
    #adr2 = tb.gen_linear_address_seq(start_address, range(20, (repeat*4)*2, 4))

    
    tb.ifu_response_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,10))
    tb.lsu_response_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,10))
    tb.m2_response_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,10))

    tb.s1_request_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,5))
        

    tb.master_delay_func = partial(ObiXbarTB.random_backpressure, data=range(0,10))
    tb.slave_delay_func = partial(ObiXbarTB.random_backpressure, data=range(0,10))
    

    m0 = tb.schedule(
        linear_read_seq_bp(
            request_driver=tb.ifu_mapped_request_driver,
            request_backpressure_driver=tb.s1_obi_request_backpressure_driver,
            request_monitor=tb.s1_obi_request_monitor,
            response_driver=tb.s1_obi_response_driver,
            response_backpressure_driver=tb.ifu_mapped_response_backpressure_driver,
            strb=0,
            tb=tb,
            addresses=address_sequence
        )
    )
    m1 = tb.schedule(
        linear_read_seq_bp(
            request_driver=tb.lsu_mapped_request_driver,
            request_backpressure_driver=tb.s1_obi_request_backpressure_driver,
            request_monitor=tb.s1_obi_request_monitor,
            response_driver=tb.s1_obi_response_driver,
            response_backpressure_driver=tb.lsu_mapped_response_backpressure_driver,
            strb=1,
            tb=tb,
            addresses=address_sequence
        )
    )
    m2 = tb.schedule(
        linear_read_seq_bp(
            request_driver=tb.m2_mapped_request_driver,
            request_backpressure_driver=tb.s1_obi_request_backpressure_driver,
            request_monitor=tb.s1_obi_request_monitor,
            response_driver=tb.s1_obi_response_driver,
            response_backpressure_driver=tb.m2_mapped_response_backpressure_driver,
            strb=2,
            tb=tb,
            addresses=address_sequence
        )
    )

    await m0,m1,m2



@ObiXbarTB.testcase(timeout=800000)
@ObiXbarTB.parameter("transactions", int, 333)
@ObiXbarTB.parameter("repeat", int, 5)
@ObiXbarTB.parameter("start_address", int, int("4000_0000", 16))
async def ifu_lsu_m2_linear_read_bp_test3_1(
    tb: ObiXbarTB,
    log,
    transactions,
    repeat,
    start_address
): 
    
    #adr2 = tb.gen_linear_address_seq(start_address, range(20, (repeat*4)*2, 4))

    
    tb.ifu_response_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,1))
    tb.lsu_response_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,1))
    tb.m2_response_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,1))

    tb.s1_request_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,50))
        

    tb.master_delay_func = partial(ObiXbarTB.random_backpressure, data=range(0,150))
    tb.slave_delay_func = partial(ObiXbarTB.random_backpressure, data=range(0,1))
    
    for i in range(repeat):
        test_mem = gen_memory_data(start_address, range(1, (transactions+1)))
        tb.mmio_device.flash(test_mem)
        address_sequence = tb.gen_linear_address_seq(start_address, range(0, (transactions*4), 4))

        m0 = tb.schedule(
            linear_read_seq_bp(
                request_driver=tb.ifu_mapped_request_driver,
                request_backpressure_driver=tb.s1_obi_request_backpressure_driver,
                request_monitor=tb.s1_obi_request_monitor,
                response_driver=tb.s1_obi_response_driver,
                response_backpressure_driver=tb.ifu_mapped_response_backpressure_driver,
                strb=0,
                tb=tb,
                addresses=address_sequence
            )
        )
        m1 = tb.schedule(
            linear_read_seq_bp(
                request_driver=tb.lsu_mapped_request_driver,
                request_backpressure_driver=tb.s1_obi_request_backpressure_driver,
                request_monitor=tb.s1_obi_request_monitor,
                response_driver=tb.s1_obi_response_driver,
                response_backpressure_driver=tb.lsu_mapped_response_backpressure_driver,
                strb=1,
                tb=tb,
                addresses=address_sequence
            )
        )
        m2 = tb.schedule(
            linear_read_seq_bp(
                request_driver=tb.m2_mapped_request_driver,
                request_backpressure_driver=tb.s1_obi_request_backpressure_driver,
                request_monitor=tb.s1_obi_request_monitor,
                response_driver=tb.s1_obi_response_driver,
                response_backpressure_driver=tb.m2_mapped_response_backpressure_driver,
                strb=2,
                tb=tb,
                addresses=address_sequence
            )
        )

        await m0,m1,m2
        transactions = int(transactions + (transactions/2))
        try:
            await ClockCycles(tb.clk, 100)
            #await tb.m2_mapped_request_driver.idle()
            #await tb.lsu_mapped_request_driver.idle()
            #await tb.ifu_mapped_request_driver.idle()
            await tb.scoreboard.drain()
            await ClockCycles(tb.clk, 500)
            await tb.scoreboard.drain()
            await ClockCycles(tb.clk, 500)
            #transactions = transactions + 10
            await tb.reset()
        except Exception as e:
            tb._orch_log.error(f"Caught exception during reset: {e}")
            raise e
        


@ObiXbarTB.testcase(timeout=800000)
@ObiXbarTB.parameter("transactions", int, 150)
@ObiXbarTB.parameter("repeat", int, 8)
@ObiXbarTB.parameter("start_address_s0", int, int("0000_0000", 16))
@ObiXbarTB.parameter("start_address_s1", int, int("4000_0000", 16))
async def test4_0_3m_2s_r(
    tb: ObiXbarTB,
    log,
    transactions,
    repeat,
    start_address_s0,
    start_address_s1

): 
    
    #adr2 = tb.gen_linear_address_seq(start_address, range(20, (repeat*4)*2, 4))

    
    tb.ifu_response_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,8))
    tb.lsu_response_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,8))
    tb.m2_response_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,8))

    tb.s0_request_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,3))
    tb.s1_request_backpressure_func = partial(ObiXbarTB.random_backpressure, data=range(0,3))
        

    tb.master_delay_func = partial(ObiXbarTB.random_backpressure, data=range(0,5))
    tb.slave_delay_func = partial(ObiXbarTB.random_backpressure, data=range(0,1))
    
    for i in range(repeat):
        test_mem = gen_memory_data(start_address_s0, range(1, int(transactions*2+1)))
        test_mem.update(gen_memory_data(start_address_s1, range(1, int(transactions*2+1))))
        tb.mmio_device.flash(test_mem)
        address_sequence = tb.gen_linear_address_seq(start_address_s0, range(0, int(transactions)*4, 4))
        address_sequence.extend(tb.gen_linear_address_seq(start_address_s1, range(0, (int(transactions)*4), 4)))

        tb.random.shuffle(address_sequence)
        m0 = tb.schedule(
            linear_read_seq_bp(
                request_driver=tb.ifu_mapped_request_driver,
                request_backpressure_driver=tb.s1_obi_request_backpressure_driver,
                request_monitor=tb.s1_obi_request_monitor,
                response_driver=tb.s1_obi_response_driver,
                response_backpressure_driver=tb.ifu_mapped_response_backpressure_driver,
                strb=0,
                tb=tb,
                addresses=address_sequence
            )
        )
        tb.random.shuffle(address_sequence)
        m1 = tb.schedule(
            linear_read_seq_bp(
                request_driver=tb.lsu_mapped_request_driver,
                request_backpressure_driver=tb.s1_obi_request_backpressure_driver,
                request_monitor=tb.s1_obi_request_monitor,
                response_driver=tb.s1_obi_response_driver,
                response_backpressure_driver=tb.lsu_mapped_response_backpressure_driver,
                strb=1,
                tb=tb,
                addresses=address_sequence
            )
        )
        m2 = tb.schedule(
            linear_read_seq_bp(
                request_driver=tb.m2_mapped_request_driver,
                request_backpressure_driver=tb.s1_obi_request_backpressure_driver,
                request_monitor=tb.s1_obi_request_monitor,
                response_driver=tb.s1_obi_response_driver,
                response_backpressure_driver=tb.m2_mapped_response_backpressure_driver,
                strb=2,
                tb=tb,
                addresses=tb.gen_linear_address_seq(start_address_s1, range(0, (transactions*4), 4))
            )
        )

        await m0,m1,m2
        transactions = int(transactions + (transactions/2))
        try:
            await ClockCycles(tb.clk, 100)
            #await tb.m2_mapped_request_driver.idle()
            #await tb.lsu_mapped_request_driver.idle()
            #await tb.ifu_mapped_request_driver.idle()
            await tb.scoreboard.drain()
            await ClockCycles(tb.clk, 500)
            await tb.scoreboard.drain()
            await ClockCycles(tb.clk, 500)
            #transactions = transactions + 10
            await tb.reset()
        except Exception as e:
            tb._orch_log.error(f"Caught exception during reset: {e}")
            raise e




if __name__ == "__main__":
    sys.path.insert(0, '/foss/designs/rvj1-SoC/soc_tb_lib')
    test_obi_crossbar_runner()