package main

import "core:fmt"

ctrlreg: u32
tcmdatasize: u32
tcminstrsize: u32

cp15_read :: proc(CRn: u32, CRm: u32, CP: u32) -> u32 {
    code := (CRn << 8) | (CRm << 4) | CP
    switch(code) {
    case 0x000: // Main ID Register
        return 0x41059461
    case 0x001: // Cache Type Register
        return 0x0F0D2112
    case 0x002: // TCM Type Register
        return 0x00140180
    case 0x100: // Control Register
        return ctrlreg
    case 0x910: // TCM Data TCM Base and Virtual Size
        return tcmdatasize
    case 0x911: // TCM Instruction TCM Base and Virtual Size
        return tcminstrsize
    case:
        fmt.println("CP15 Read", CRn, CRm, CP)
        fmt.printfln("Code %X", code)
    }
    return 0
}

cp15_write :: proc(CRn: u32, CRm: u32, CP: u32, value: u32) {
    code := (CRn << 8) | (CRm << 4) | CP
    switch(code) {
    case 0x100: // Control Register
        ctrlreg = value
    case 0x750: // Invalidate Entire Instruction Cache
        // Cache not implemented
    case 0x760: // Invalidate Entire Data Cache
        // Cache not implemented
    case 0x7A4: // Drain Write Buffer
        // Cache not implemented
    case 0x910: // TCM Data TCM Base and Virtual Size
        tcmdatasize = value
    case 0x911: // TCM Instruction TCM Base and Virtual Size
        tcminstrsize = value
    case:
        fmt.println("CP15 Write", CRn, CRm, CP, value)
        fmt.printfln("Code %X", code)
    }
}