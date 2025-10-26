package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "../../odin-libs/cpu/arm7"

Bus :: struct {
    read8: proc(addr: u32, width: u8) -> u8,
    read16: proc(addr: u32) -> u16,
    read32: proc(addr: u32) -> u32,
    write8: proc(addr: u32, value: u8, width: u8),
    write16: proc(addr: u32, value: u16),
    write32: proc(addr: u32, value: u32),
    get8: proc(addr: u32) -> u8,
    get16: proc(addr: u32) -> u16,
    get32: proc(addr: u32) -> u32,
    set8: proc(addr: u32, value: u8),
    set16: proc(addr: u32, value: u16),
    set32: proc(addr: u32, value: u32),
    irq_set: proc(bit: u8),
}

@(private="file")
mem: [0xFFFFFFF]u8
@(private="file")
bus7: Bus

bus7_init :: proc() {
    bus7.read8 = bus7_read8
    bus7.read16 = bus7_read16
    bus7.read32 = bus7_read32
    bus7.write8 = bus7_write8
    bus7.write16 = bus7_write16
    bus7.write32 = bus7_write32
    bus7.get8 = bus7_get8
    bus7.get16 = bus7_get16
    bus7.get32 = bus7_get32
    bus7.set8 = bus7_set8
    bus7.set16 = bus7_set16
    bus7.set32 = bus7_set32
    bus7.irq_set = bus7_irq_set

    arm7.bus_read8 = bus7_read8
    arm7.bus_read16 = bus7_read16
    arm7.bus_read32 = bus7_read32
    arm7.bus_write8 = bus7_write8
    arm7.bus_write16 = bus7_write16
    arm7.bus_write32 = bus7_write32
    arm7.bus_get16 = bus7_get16
    arm7.bus_get32 = bus7_get32
}

bus7_reset :: proc() {
    mem = {}
    bus7_load_bios()
}

bus7_load_bios :: proc() {
    file, err := os.open("biosnds9.rom", os.O_RDONLY)
    assert(err == nil, "Failed to open bios")
    _, err2 := os.read(file, mem[:])
    assert(err2 == nil, "Failed to read bios data")
    os.close(file)
}

bus7_load_rom :: proc(file: os.Handle) {
    os.seek(file, cast(i64)(rom_header.rom_offset7), os.SEEK_SET)
    os.read(file, mem[rom_header.ram_address7:rom_header.ram_address7 + rom_header.size7])
}

bus7_get8 :: proc(addr: u32) -> u8 {
    return mem[addr]
}

bus7_set8 :: proc(addr: u32, value: u8) {
    mem[addr] = value
}

bus7_read8 :: proc(addr: u32, width: u8 = 1) -> u8 {
    addr := addr
    addr_id := addr & 0xFF000000
    switch(addr_id) {
    case 0x00000000: //BIOS
        break
    case 0x02000000: //WRAM
        addr &= 0x32FFFFF
        break
    case 0x03000000: //WRAM
        //addr &= 0x3007FFF
        break
    case 0x04000000: //IO
        switch(addr) {
        case:
            fmt.printfln("7 Addr read 8 %X", addr)
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
    }
    return mem[addr]
}

bus7_write8 :: proc(addr: u32, value: u8, width: u8 = 1) {
    addr := addr
    addr_id := addr & 0xF000000
    switch(addr_id) {
    case 0x0000000: //BIOS
        return //Read only
    case 0x2000000: //WRAM
        addr &= 0x32FFFFF
        break
    case 0x3000000: //WRAM
        //addr &= 0x3007FFF
        break
    case 0x4000000: //IO
        //fmt.printfln("%X %d",addr, value)
        switch(addr) {

        case:
            fmt.printfln("7 Addr write 8 %X", addr)
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

bus7_get16 :: proc(addr: u32) -> u16 {
    return (cast(^u16)&mem[addr])^
}

bus7_set16 :: proc(addr: u32, value: u16) {
    (cast(^u16)&mem[addr])^ = value
}

bus7_read16 :: proc(addr: u32) -> u16 {
    addr := addr
    addr &= 0xFFFFFFFE

    if((addr & 0xF000000) == 0x4000000 ) {
        switch(addr) {
        case 0x4000180:
            return 0
            //TODO: Implement IPC
        case 0x4000184:
            return 0xFF
            //TODO: Implement IPC FIFO
        case:
            fmt.printfln("7 Addr read 16 %X", addr)
        }
        return 0
    } else {
        value := u16(bus7_read8(addr, 2))
        value |= (u16(bus7_read8(addr + 1, 2))) << 8
        return value
    }
}

bus7_write16 :: proc(addr: u32, value: u16) {
    addr := addr
    addr &= 0xFFFFFFFE

    if((addr & 0xF000000) == 0x4000000 ) {
        switch(addr) {
        case 0x4000180:
            //TODO: Implement IPC
        case:
            fmt.printfln("7 Addr write 16 %X", addr)
        }
    } else {
        bus7_write8(addr, u8(value & 0x00FF), 2)
        bus7_write8(addr + 1, u8((value & 0xFF00) >> 8), 2)
    }
}

bus7_get32 :: proc(addr: u32) -> u32 {
    addr := addr
    addr &= 0xFFFFFFFC
    return (cast(^u32)&mem[addr])^
}

bus7_set32 :: proc(addr: u32, value: u32) {
    (cast(^u32)&mem[addr])^ = value
}

bus7_read32 :: proc(addr: u32) -> u32 {
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
            fmt.printfln("7 Addr read 32 %X", addr)
        }
        return 0
    } else {
        value := u32(bus7_read8(addr, 4))
        value |= (u32(bus7_read8(addr + 1, 4)) << 8)
        value |= (u32(bus7_read8(addr + 2, 4)) << 16)
        value |= (u32(bus7_read8(addr + 3, 4)) << 24)
        return value
    }
}

bus7_write32 :: proc(addr: u32, value: u32) {
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
            fmt.printfln("7 Addr write 32 %X", addr)
        }
    } else {
        bus7_write8(addr, u8(value & 0x000000FF))
        bus7_write8(addr + 1, u8((value & 0x0000FF00) >> 8), 4)
        bus7_write8(addr + 2, u8((value & 0x00FF0000) >> 16), 4)
        bus7_write8(addr + 3, u8((value & 0xFF000000) >> 24), 4)
    }
}

bus7_irq_set :: proc(bit: u8) {
    iflag := bus7_get16(IO_IF)
    bus7_set16(IO_IF, utils_bit_set16(iflag, bit))
}