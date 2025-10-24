package main

import "core:math"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "../../odin-libs/cpu/arm9"

Rom_header :: struct {
    rom_offset9: u32,
    entry_address9: u32,
    ram_address9: u32,
    size9: u32,
    rom_offset7: u32,
    entry_address7: u32,
    ram_address7: u32,
    size7: u32,
}

@(private="file")
mem: [0xFFFFFFF]u8
@(private="file")
bios: [0x1000]u8
@(private="file")
bus9: Bus
rom_header: Rom_header

bus9_init :: proc() {
    bus9.read8 = bus9_read8
    bus9.read16 = bus9_read16
    bus9.read32 = bus9_read32
    bus9.write8 = bus9_write8
    bus9.write16 = bus9_write16
    bus9.write32 = bus9_write32
    bus9.get8 = bus9_get8
    bus9.get16 = bus9_get16
    bus9.get32 = bus9_get32
    bus9.set8 = bus9_set8
    bus9.set16 = bus9_set16
    bus9.set32 = bus9_set32
    bus9.irq_set = bus9_irq_set

    arm9.bus_read8 = bus9_read8
    arm9.bus_read16 = bus9_read16
    arm9.bus_read32 = bus9_read32
    arm9.bus_write8 = bus9_write8
    arm9.bus_write16 = bus9_write16
    arm9.bus_write32 = bus9_write32
    arm9.bus_get16 = bus9_get16
    arm9.bus_get32 = bus9_get32
    arm9.cp15_read = cp15_read
    arm9.cp15_write = cp15_write
}

bus9_reset :: proc() {
    mem = {}
    bus9_load_bios()
}

bus9_load_bios :: proc() {
    file, err := os.open("biosnds9.rom", os.O_RDONLY)
    assert(err == nil, "Failed to open bios")
    _, err2 := os.read(file, bios[:])
    assert(err2 == nil, "Failed to read bios data")
    os.close(file)
}

bus9_load_rom :: proc(path: string) {
    file, err := os.open(path, os.O_RDONLY)
    assert(err == nil, "Failed to open rom")

    //Read rom header
    os.seek(file, 0x20, os.SEEK_SET)
    tmp_mem: [32]u8
    _, err = os.read(file, tmp_mem[:])
    rom_header = (cast(^Rom_header)&tmp_mem[0])^

    //Load rom data arm9
    os.seek(file, cast(i64)(rom_header.rom_offset9), os.SEEK_SET)
    os.read(file, mem[rom_header.ram_address9:rom_header.ram_address9 + rom_header.size9])

    bus7_load_rom(file)
    file_name = filepath.short_stem(path)
    os.close(file)
}

bus9_get8 :: proc(addr: u32) -> u8 {
    return mem[addr]
}

bus9_set8 :: proc(addr: u32, value: u8) {
    mem[addr] = value
}

bus9_read8 :: proc(addr: u32, width: u8 = 1) -> u8 {
    addr := addr
    addr_id := addr & 0xFF000000
    switch(addr_id) {
    case 0x00000000: //Instruction TCM
        break
    case 0x02000000: //WRAM
        addr &= 0x32FFFFF
        break
    case 0x03000000: //WRAM
        addr &= 0x3007FFF
        break
    case 0x04000000: //IO
        switch(addr) {
        case:
            fmt.printfln("9 Addr read 8 %X", addr)
            return mem[addr]
        }
        break
    case 0x05000000: //Palette RAM
        addr &= 0x50004FF
        break
    case 0x06000000: //VRAM
        /*addr &= 0x601FFFF
        if(addr >= 0x6018000) {
            addr -= 0x8000
        }*/
        break
    case 0x07000000: //OBJ RAM
        addr &= 0x70004FF
        break
    case 0xFF000000: //BIOS
        return bios[addr - 0xFFFF0000]
    }
    return mem[addr]
}

bus9_write8 :: proc(addr: u32, value: u8, width: u8 = 1) {
    addr := addr
    addr_id := addr & 0xF000000
    switch(addr_id) {
    case 0x0000000: //BIOS
        return //Read only
    case 0x2000000: //WRAM
        addr &= 0x32FFFFF
        break
    case 0x3000000: //WRAM
        addr &= 0x3007FFF
        break
    case 0x4000000: //IO
        //fmt.printfln("%X %d",addr, value)
        switch(addr) {
        case:
            fmt.printfln("9 Addr write 8 %X", addr)
            mem[addr] = value
        }
        return
    case 0x5000000: //Palette RAM
        addr &= 0x50004FF
        if width == 1 { //TODO: Hacky fix, do a better job at implementing,
            addr &= 0xFFFFFFFE
            mem[addr] = value
            mem[addr + 1] = value
            return
        }
        break
    case 0x6000000: //VRAM
        //addr &= 0x601FFFF
        break
    case 0x7000000: //OBJ RAM
        addr &= 0x70004FF
        break
    case 0x8000000, //ROM
         0x9000000,
         0xA000000,
         0xB000000,
         0xC000000,
         0xD000000:
        return //Read only
    }
    mem[addr] = value
}

bus9_get16 :: proc(addr: u32) -> u16 {
    return (cast(^u16)&mem[addr])^
}

bus9_set16 :: proc(addr: u32, value: u16) {
    (cast(^u16)&mem[addr])^ = value
}

bus9_read16 :: proc(addr: u32) -> u16 {
    addr := addr
    addr &= 0xFFFFFFFE

    if((addr & 0xF000000) == 0x4000000 ) {
        switch(addr) {
        case 0x4000004:
            return ppu_read16(addr)
        case 0x4000130:
            return input_read16(addr)
        case 0x4000180:
            //TODO: Implement IPC
            return 0
        case 0x40002B0, 0x4000280:
            return math_read16(addr)
        case:
            fmt.printfln("9 Addr read 16 %X", addr)
        }
        return 0
    } else {
        value := u16(bus9_read8(addr, 2))
        value |= (u16(bus9_read8(addr + 1, 2))) << 8
        return value
    }
}

bus9_write16 :: proc(addr: u32, value: u16) {
    addr := addr
    addr &= 0xFFFFFFFE

    if((addr & 0xF000000) == 0x4000000 ) {
        switch(addr) {
        case 0x4000180:
            //TODO: Implement IPC
        case IO_IME:
            bus9_set16(addr, value)
        case 0x4000280, 0x40002B0:
            math_write16(addr, value)
        case:
            fmt.printfln("9 Addr write 16 %X", addr)
        }
    } else {
        bus9_write8(addr, u8(value & 0x00FF), 2)
        bus9_write8(addr + 1, u8((value & 0xFF00) >> 8), 2)
    }
}

bus9_get32 :: proc(addr: u32) -> u32 {
    addr := addr
    addr &= 0xFFFFFFFC
    if(addr >= 0xFFFF0000) {
        return (cast(^u32)&bios[addr - 0xFFFF0000])^
    } else {
        return (cast(^u32)&mem[addr])^
    }
}

bus9_set32 :: proc(addr: u32, value: u32) {
    (cast(^u32)&mem[addr])^ = value
}

bus9_read32 :: proc(addr: u32) -> u32 {
    addr := addr
    addr &= 0xFFFFFFFC

    if((addr & 0xF000000) == 0x4000000 ) {
        switch(addr) {
        case IO_IME:
            return bus9_get32(addr)
        case IO_IE:
            return bus9_get32(addr)
        case IO_IF:
            return bus9_get32(addr)
        case 0x40002B4, 0x40002A0, 0x40002A4,
             0x40002A8, 0x40002AC:
            return math_read32(addr)
        case:
            fmt.printfln("9 Addr read 32 %X", addr)
        }
        return 0
    } else {
        value := u32(bus9_read8(addr, 4))
        value |= (u32(bus9_read8(addr + 1, 4)) << 8)
        value |= (u32(bus9_read8(addr + 2, 4)) << 16)
        value |= (u32(bus9_read8(addr + 3, 4)) << 24)
        return value
    }
}

bus9_write32 :: proc(addr: u32, value: u32) {
    addr := addr
    addr &= 0xFFFFFFFC

    if((addr & 0xF000000) == 0x4000000 ) {
        switch(addr) {
        case 0x4000000:
            ppu_write32(addr, value)
        case IO_IME:
            bus9_set32(addr, value)
        case IO_IE:
            bus9_set32(addr, value)
        case IO_IF:
            bus9_set32(addr, ~value & bus9_get32(addr))
        case 0x40002B8, 0x40002BC, 0x4000290,
             0x4000294, 0x4000298, 0x400029C:
            math_write32(addr, value)
        case:
            fmt.printfln("9 Addr write 32 %X", addr)
        }
    } else {
        bus9_write8(addr, u8(value & 0x000000FF))
        bus9_write8(addr + 1, u8((value & 0x0000FF00) >> 8), 4)
        bus9_write8(addr + 2, u8((value & 0x00FF0000) >> 16), 4)
        bus9_write8(addr + 3, u8((value & 0xFF000000) >> 24), 4)
    }
}

bus9_irq_set :: proc(bit: u8) {
    iflag := bus9_get32(IO_IF)
    bus9_set32(IO_IF, utils_bit_set32(iflag, bit))
}