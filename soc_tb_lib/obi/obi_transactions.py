from dataclasses import dataclass, field
from enum import IntEnum, auto

from forastero import BaseTransaction

import dataclasses

class ObiAccess(IntEnum):
    READ = 0
    WRITE = 1

@dataclass(kw_only=True)
class ObiRequest(BaseTransaction):
    valid_delay: int = 0
    obi_aadr: int = 0
    obi_awe: ObiAccess = ObiAccess.READ
    obi_abe: int = 0b1111
    obi_awdata: int = 0
    obi_mid: int = dataclasses.field(default=0, compare=False)
    obi_aid: int = dataclasses.field(default=0, compare=False)

@dataclass(kw_only=True)
class ObiResponse(BaseTransaction):
    valid_delay: int = 0
    obi_rdata: int = 0
    obi_rerr: int = 0
    obi_rid: int = 0
    obi_mid: int = 0

@dataclass(kw_only=True)
class ObiBackpressure(BaseTransaction):
    ready: bool = True
    cycles: int = 1
    
