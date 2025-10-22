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
    case 0x200: // Cachability Bits for Data/Unified Protection Region
        return 0
    case 0x201: // Cachability Bits for Instruction Protection Region
        return 0
    case 0x300: // Cache Write-Bufferability Bits for Data Protection Regions
        return 0
    case 0x500: // Access Permission Data/Unified Protection Region
        return 0
    case 0x501: // Access Permission Instruction Protection Region
        return 0
    case 0x502: // Extended Access Permission Data/Unified Protection Region
        return 0
    case 0x503: // Extended Access Permission Instruction Protection Region
        return 0
    case 0x600: // Protection Unit Data/Unified Region 0
        return 0
    case 0x610: // Protection Unit Data/Unified Region 1
        return 0
    case 0x620: // Protection Unit Data/Unified Region 2
        return 0
    case 0x630: // Protection Unit Data/Unified Region 3
        return 0
    case 0x640: // Protection Unit Data/Unified Region 4
        return 0
    case 0x650: // Protection Unit Data/Unified Region 5
        return 0
    case 0x660: // Protection Unit Data/Unified Region 6
        return 0
    case 0x670: // Protection Unit Data/Unified Region 7
        return 0
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