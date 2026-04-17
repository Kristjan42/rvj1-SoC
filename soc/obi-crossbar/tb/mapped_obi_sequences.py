import forastero
from cocotb.triggers import ClockCycles
from forastero.driver import DriverEvent
from forastero.sequence import SeqContext, SeqProxy

from forastero_io.mapped.request import MappedRequestInitiator, MappedRequestResponder
from forastero_io.mapped.response import MappedResponseInitiator, MappedResponseResponder
from forastero_io.mapped.transaction import MappedAccess, MappedBackpressure, MappedRequest, MappedResponse
from test_obi_crossbar import ObiXbarTB

@forastero.sequence()
@forastero.requires("driver", MappedRequestInitiator)
async def linear_read_seq(
    ctx: SeqContext,
    driver: SeqProxy[MappedRequestInitiator],
    tb: ObiXbarTB,
    addresses: list[int] | None = None,
) -> None:
    for addr in addresses:
        async with ctx.lock(driver):
            driver.enqueue(
                MappedRequest(
                    cycles=tb.master_delay_func(tb),
                    address=addr,
                    mode=MappedAccess.READ,
                ),
                DriverEvent.POST_DRIVE
            ).wait()

@forastero.sequence()
@forastero.requires("driver", MappedRequestInitiator)
async def random_read_seq(
    ctx: SeqContext,
    driver: SeqProxy[MappedRequestInitiator],
    tb: ObiXbarTB,
    count: 1000,
    addresses: list[int] | None = None,
) -> None:
    for _ in range(count):
        addr = addresses[ctx.random.randrange(0, len(addresses))]
        async with ctx.lock(driver):
            driver.enqueue(
                MappedRequest(
                    cycles=tb.master_delay_func(tb),
                    address=addr,
                    mode=MappedAccess.READ,
                ),
                DriverEvent.POST_DRIVE
            ).wait()

@forastero.sequence()
@forastero.requires("driver", MappedRequestInitiator)
async def linear_write_seq(
    ctx: SeqContext,
    driver: SeqProxy[MappedRequestInitiator],
    tb: ObiXbarTB,
    addresses: list[int] | None = None,
    data: list[int] | None = None,
    strobe: list[int] | None = None,
) -> None:
    for addr, value, strb in zip(addresses, data, strobe):
        async with ctx.lock(driver):
            driver.enqueue(
                MappedRequest(
                    cycles=tb.master_delay_func(tb),
                    address=addr,
                    mode=MappedAccess.WRITE,
                    data=value,
                    strobe=strb
                ),
                DriverEvent.POST_DRIVE
            ).wait()

@forastero.sequence()
@forastero.requires("driver", MappedRequestInitiator)
async def random_write_seq(
    ctx: SeqContext,
    driver: SeqProxy[MappedRequestInitiator],
    tb: ObiXbarTB,
    count: 1000,
    addresses: list[int] | None = None,
    data: list[int] | None = None,
    strobe: list[int] | None = None,
) -> None:
    for _ in range(count):
        addr = addresses[ctx.random.randrange(0, len(addresses))]
        value = data[ctx.random.randrange(0, len(data))]
        strb = strobe[ctx.random.randrange(0, len(strobe))]
        async with ctx.lock(driver):
            driver.enqueue(
                MappedRequest(
                    cycles=tb.master_delay_func(tb),
                    address=addr,
                    mode=MappedAccess.WRITE,
                    data=value,
                    strobe=strb
                ),
                DriverEvent.POST_DRIVE
            ).wait()