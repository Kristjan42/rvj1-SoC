

class Memory_device:
    def __init__(
            self,
            memory: dict[int, int] = {}
    ) -> None:
        self._memory = memory

    def flash(self, memory: dict[int, int]) -> None:
        self._memory = memory
        
    def reset(self) -> None:
        self._memory.clear()

    def read(self, addr: int) -> int | None:
        if addr not in self._memory:
            return None
        return self._memory[addr]

    def write(self, addr: int, data: int, strobe: int) -> bool:
        if strobe not in (0b1111, 0b0011, 0b1100, 0b1000, 0b0100, 0b0010, 0b0001):
            return 1
        waddr = addr - (addr % 4)  # get word addr
        strs = format(strobe, "04b")  # returns "1111" string
        mask = (
            (int(strs[0]) * 0xFF << 24)
            + (int(strs[1]) * 0xFF << 16)
            + (int(strs[2]) * 0xFF << 8)
            + (int(strs[3]) * 0xFF)
        )
        if waddr not in self._memory:
            prev_data = 0
            err = 1
        else:
            prev_data = self._memory[waddr]
            err = 0
        self._memory[waddr] = (prev_data & ~mask) + (data & mask)
        return err

    def __str__(self) -> str:
        ret = "ApbSlaveDeviceMemory(\n"
        for addr, val in self._memory.items():
            ret += f"\t0x{addr:08x} : {val}\n"
        ret += ")\n"
        return ret
    
def gen_memory_data(base_addr: int, data: list[int]) -> dict[int, int]:
    mem = {}
    assert len(data) > 0
    assert base_addr % 4 == 0
    for ind, da in enumerate(data):
        addr = base_addr + 4 * ind
        mem[addr] = da
    return mem