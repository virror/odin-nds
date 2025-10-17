package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "../../odin-libs/cpu"

mem: [0xFFFFFFF]u8
bios: [0x1000]u8
ram_write: bool
start_offset: u32

bus_init :: proc() {
    cpu.bus_read8 = bus_read8
    cpu.bus_read16 = bus_read16
    cpu.bus_read32 = bus_read32
    cpu.bus_write8 = bus_write8
    cpu.bus_write16 = bus_write16
    cpu.bus_write32 = bus_write32
    cpu.bus_get16 = bus_get16
    cpu.bus_get32 = bus_get32
    cpu.cp15_read = cp15_read
    cpu.cp15_write = cp15_write
}

bus_reset :: proc() {
    mem = {}
    ram_write = false
    bus_load_bios()
}

bus_load_bios :: proc() {
    file, err := os.open("biosnds9.rom", os.O_RDONLY)
    assert(err == nil, "Failed to open bios")
    _, err2 := os.read(file, bios[:])
    assert(err2 == nil, "Failed to read bios data")
    os.close(file)
}

bus_load_rom :: proc(path: string) {
    file, err := os.open(path, os.O_RDONLY)
    assert(err == nil, "Failed to open rom")
    _, err2 := os.read(file, mem[0x08000000:])
    assert(err2 == nil, "Failed to read rom data")
    file_name = filepath.short_stem(path)
    os.close(file)
    start_offset = (cast(^u32)&mem[0x08000020])^
}

bus_get8 :: proc(addr: u32) -> u8 {
    return mem[addr]
}

bus_set8 :: proc(addr: u32, value: u8) {
    mem[addr] = value
}

bus_read8 :: proc(addr: u32, width: u8 = 1) -> u8 {
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
        case 0x4000000..=0x400005F:
            return ppu_read(addr)
        case 0x4000060..=0x40000AF:
            return apu_read(addr)
        case 0x40000B0..=0x40000FF:
            return dma_read(addr)
        case 0x4000100..=0x4000110:
            return tmr_read(addr)
        case 0x4000120..=0x400012F:
            return srl_read(addr)
        case 0x4000130..=0x4000132:
            return input_read(addr)
        case 0x4000134..=0x40001FF:
            return srl_read(addr)
        case 0x4000206..=0x4000207,
                0x400020A..=0x40002FF,
                0x4000302..=0x40007FF:
            return 0
        case 0x4000804..=0x4FFFFFF:
            if((addr & 1) > 0) {
                return 0xDE
            } else {
                return 0xAD
            }
        case:
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

bus_write8 :: proc(addr: u32, value: u8, width: u8 = 1) {
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
        fmt.printfln("%X %d",addr, value)
        switch(addr) {
        case 0x4000000..=0x400005F:
            ppu_write(addr, value)
        case 0x4000060..=0x40000AF:
            apu_write(addr, value)
        case 0x40000B0..=0x40000FF:
            dma_write(addr, value)
        case 0x4000100..=0x4000110:
            tmr_write(addr, value)
        case 0x4000120..=0x400012F:
            srl_write(addr, value)
        case 0x4000130..=0x4000132:
            input_write(addr, value)
        case 0x4000134..=0x40001FF:
            srl_write(addr, value)
        case IO_IF, IO_IF + 1:
            mem[addr] = (~value) & mem[addr]
        case IO_IME:
            mem[addr] = value
        case IO_HALTCNT:
            if(utils_bit_get16(u16(value), 7)) {
                cpu.arm9_stop()
            } else {
                cpu.arm9_halt()
            }
        case:
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

bus_get16 :: proc(addr: u32) -> u16 {
    return (cast(^u16)&mem[addr])^
}

bus_set16 :: proc(addr: u32, value: u16) {
    (cast(^u16)&mem[addr])^ = value
}

bus_read16 :: proc(addr: u32) -> u16 {
    addr := addr
    addr &= 0xFFFFFFFE
    value := u16(bus_read8(addr, 2))
    value |= (u16(bus_read8(addr + 1, 2))) << 8
    return value
}

bus_write16 :: proc(addr: u32, value: u16) {
    addr := addr
    addr &= 0xFFFFFFFE
    bus_write8(addr, u8(value & 0x00FF), 2)
    bus_write8(addr + 1, u8((value & 0xFF00) >> 8), 2)
}

bus_get32 :: proc(addr: u32) -> u32 {
    addr := addr
    addr &= 0xFFFFFFFC
    if(addr >= 0xFFFF0000) {
        return (cast(^u32)&bios[addr - 0xFFFF0000])^
    } else {
        return (cast(^u32)&mem[addr])^
    }
}

bus_set32 :: proc(addr: u32, value: u32) {
    (cast(^u32)&mem[addr])^ = value
}

bus_read32 :: proc(addr: u32) -> u32 {
    addr := addr
    addr &= 0xFFFFFFFC
    value := u32(bus_read8(addr, 4))
    value |= (u32(bus_read8(addr + 1, 4)) << 8)
    value |= (u32(bus_read8(addr + 2, 4)) << 16)
    value |= (u32(bus_read8(addr + 3, 4)) << 24)
    return value
}

bus_write32 :: proc(addr: u32, value: u32) {
    addr := addr
    addr &= 0xFFFFFFFC
    bus_write8(addr, u8(value & 0x000000FF))
    bus_write8(addr + 1, u8((value & 0x0000FF00) >> 8), 4)
    bus_write8(addr + 2, u8((value & 0x00FF0000) >> 16), 4)
    bus_write8(addr + 3, u8((value & 0xFF000000) >> 24), 4)
}

bus_irq_set :: proc(bit: u8) {
    iflag := bus_get32(IO_IF)
    bus_set32(IO_IF, utils_bit_set32(iflag, bit))
}