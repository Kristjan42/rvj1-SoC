from forastero.io import BaseIO, IORole
from cocotb.handle import HierarchyObject
from collections.abc import Callable

class ObiRequestIO(BaseIO):
    def __init__(
        self,
        dut: HierarchyObject,
        name: str | None,
        role: IORole,
        io_style: Callable[[str | None, str, IORole, IORole], str] | None = None,
    ) -> None:
        super().__init__(
            dut=dut,
            name=name,
            role=role,
            init_sigs=["aadr", "awe", "abe", "awdata", "aid", "mid", "areq"],
            resp_sigs=["agnt"],
            io_style=io_style,
        )

class ObiResponseIO(BaseIO):
    def __init__(
        self,
        dut: HierarchyObject,
        name: str | None,
        role: IORole,
        io_style: Callable[[str | None, str, IORole, IORole], str] | None = None,
    ) -> None:
        super().__init__(
            dut=dut,
            name=name,
            role=role,
            init_sigs=["rdata", "rerr", "rid", "rvalid"],
            resp_sigs=["rready"],
            io_style=io_style,
        )