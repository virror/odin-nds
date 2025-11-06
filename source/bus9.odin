package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:container/queue"
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

Ipcfifocnt :: struct {
    send_irq: bool,
    rec_irq: bool,
    error: bool,
    enable: bool,
}

Powercnt1 :: bit_field u32 {
    lcd_enable: bool    | 1,
    geA_enable: bool    | 1,
    re_enable: bool     | 1,
    ge_enable: bool     | 1,
    na1: u8             | 5,
    geB_enable: bool    | 1,
    na2: u8             | 5,
    swap: bool          | 1,
    na3: u16            | 16,
}

Vramcnt :: bit_field u8 {
    mst: u8         | 3,
    offset: u8      | 2,
    na: u8          | 2,
    enable: bool    | 1,
}

@(private="file")
mem: [0xFFFFFFF]u8
@(private="file")
bios: [0x1000]u8
@(private="file")
bus9: Bus
rom_header: Rom_header
@(private="file")
ipc_data: u16
ipcfifo9: queue.Queue(u32)
@(private="file")
ipcfifocnt: Ipcfifocnt
@(private="file")
last_fifo: u32
wramcnt: u8
@(private="file")
itcm: [0x8000]u8
@(private="file")
dtcm: [0x4000]u8
powercnt1: Powercnt1
@(private="file")
ipcsync: u16
@(private="file")
vramcnt: [9]Vramcnt

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
    arm9.cpu_exec_irq = bus9_check_irq

	queue.init(&ipcfifo9, 16)
}

bus9_check_irq :: proc() {
    if(utils_bit_get32(bus9_get32(IO_IME), 0) && !arm9.get_cpsr().IRQ) { //IEs enabled
        if(bus9_get32(IO_IE) & bus9_get32(IO_IF) > 0) { //IE triggered
            arm9.exec_irq(u32(cp15cntreg.irq_vector) * 0xFFFF0000 + 0x18)
        }
    }
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

    if(addr < (512 << itcmsize.vsize) && cp15cntreg.itcm_enable && !cp15cntreg.itcm_load) {
        return itcm[addr & 0x7FFF]
    } else if(bus9_dtcm_inside(addr) && cp15cntreg.dtcm_enable && !cp15cntreg.dtcm_load) {
        return dtcm[addr & 0x3FFF]
    }

    addr_id := addr & 0xFF000000
    switch(addr_id) {
    case 0x00000000: //TCM
        break
    case 0x02000000: //Main RAM
        addr &= 0x23FFFFF
        break
    case 0x03000000: //WRAM
        switch(wramcnt & 3) {
        case 0:
            return mem[addr & 0x3007FFF]
        case 1:
            if(addr < 0x3004000) {
                return mem[(addr + 0x4000)]
            } else {
                return mem[addr & 0x3007FFF]
            }
        case 2:
            return mem[addr & 0x3003FFF]
        case 3:
            return 0
            }
        break
    case 0x04000000: //IO
        switch(addr) {
        case 0x4000247:
            return wramcnt
        case:
            fmt.printfln("9 Addr read 8 %X", addr)
            return mem[addr]
        }
        break
    case 0x05000000: //Palette RAM
        addr &= 0x50004FF
        break
    case 0x06000000: //VRAM
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

    if(addr < (512 << itcmsize.vsize) && cp15cntreg.itcm_enable) {
        itcm[addr & 0x7FFF] = value
        return
    } else if(bus9_dtcm_inside(addr) && cp15cntreg.dtcm_enable) {
        dtcm[addr & 0x3FFF] = value
        return
    }

    addr_id := addr & 0xF000000
    switch(addr_id) {
    case 0x0000000: //TCM
        break
    case 0x2000000: //Main RAM
        addr &= 0x23FFFFF
        break
    case 0x3000000: //WRAM
        switch(wramcnt & 3) {
        case 0:
            mem[addr & 0x3007FFF] = value
        case 1:
            if(addr < 0x3004000) {
                mem[(addr + 0x4000)] = value
            } else {
                mem[addr & 0x3007FFF] = value
            }
        case 2:
            mem[addr & 0x3003FFF] = value
        case 3:
            return
            }
        break
    case 0x4000000: //IO
        switch(addr) {
        case 0x4000240:
            vramcnt[0] = Vramcnt(value)
        case 0x4000241:
            vramcnt[1] = Vramcnt(value)
        case 0x4000242:
            vramcnt[2] = Vramcnt(value)
        case 0x4000243:
            vramcnt[3] = Vramcnt(value)
        case 0x4000244:
            vramcnt[4] = Vramcnt(value)
        case 0x4000245:
            vramcnt[5] = Vramcnt(value)
        case 0x4000246:
            vramcnt[6] = Vramcnt(value)
        case 0x4000247:
            wramcnt = value
        case 0x4000248:
            vramcnt[7] = Vramcnt(value)
        case 0x4000249:
            vramcnt[8] = Vramcnt(value)
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
    if((addr & 0xF000000) == 0x200000 ) {
        fmt.println("get16 9 from main ram")
    }
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
            return ipc_data
        case 0x4000184:
            data := u16((queue.len(ipcfifo9) == 0)?1:0)
            data |= u16((queue.space(ipcfifo9) == 0)?1:0) << 1
            data |= (ipcfifocnt.send_irq?1:0) << 2
            data |= u16((queue.len(ipcfifo7) == 0)?1:0) << 8
            data |= u16((queue.space(ipcfifo7) == 0)?1:0) << 9
            data |= (ipcfifocnt.send_irq?1:0) << 10
            data |= (ipcfifocnt.error?1:0) << 14
            data |= (ipcfifocnt.enable?1:0) << 15
            return data
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
            ipcsync = value
            bus7_ipc_write((value >> 8) & 0x0F, bool((value >> 13) & 1))
        case 0x4000184:
            ipcfifocnt.send_irq = bool((value >> 2) & 1)
            if(bool((value >> 3) & 1)) {   //Clear
                queue.clear(&ipcfifo9)
            }
            ipcfifocnt.rec_irq = bool((value >> 10) & 1)
            if(bool((value >> 14) & 1)) {   //Error
                ipcfifocnt.error = false
            }
            ipcfifocnt.enable = bool((value >> 15) & 1)
        case IO_IME:
            bus9_set16(addr, value)
        case 0x4000280, 0x40002B0:
            math_write16(addr, value)
        case 0x4000304:
            powercnt1 = Powercnt1(value)
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
    if((addr & 0xF000000) == 0x200000 ) {
        fmt.println("get32 9 from main ram")
    }
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
        case 0x4100000:
            if(ipcfifocnt.enable) {
                if(queue.len(ipcfifo7) > 0) {
                    last_fifo = queue.dequeue(&ipcfifo7)
                    if(queue.len(ipcfifo7) == 0) {
                        bus7_ipcfifo_empty()
                    }
                    return last_fifo
                } else {
                    ipcfifocnt.error = true
                    return last_fifo
                }
            } else {
                if(queue.len(ipcfifo7) > 0) {
                    last_fifo = queue.front_ptr(&ipcfifo7)^
                    return last_fifo
                } else {
                    return 0
                }
            }
        case IO_IME:
            return bus9_get32(addr)
        case IO_IE:
            return bus9_get32(addr)
        case IO_IF:
            return bus9_get32(addr)
        case 0x40002B4, 0x40002A0, 0x40002A4,
             0x40002A8, 0x40002AC:
            return math_read32(addr)
        case 0x4004008:   //Check if DSi, return 0
            return 0
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
        case 0x4000188:
            if(ipcfifocnt.enable) {
                queue.enqueue(&ipcfifo9, value)
                if(queue.len(ipcfifo9) == 1) {
                    bus7_ipcfifo_not_empty()
                }
            }
        case IO_IME:
            bus9_set32(addr, value)
        case IO_IE:
            bus9_set32(addr, value)
        case IO_IF:
            bus9_set32(addr, ~value & bus9_get32(addr))
        case 0x40002B8, 0x40002BC, 0x4000290,
             0x4000294, 0x4000298, 0x400029C:
            math_write32(addr, value)
        case 0x4000304:
            powercnt1 = Powercnt1(value)
        case:
            fmt.printfln("9 Addr write 32 %X %X", addr, value)
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

bus9_ipc_write :: proc(value: u16, irq: bool) {
    ipc_data = value
    if(irq && bool((ipcsync >> 14) & 1)) {
        bus9_irq_set(16)
    }
}

bus9_ipcfifo_not_empty :: proc() {
    if(ipcfifocnt.rec_irq) {
        bus9_irq_set(18)
    }
}

bus9_ipcfifo_empty :: proc() {
    if(ipcfifocnt.send_irq) {
        bus9_irq_set(17)
    }
}

bus9_read_wram :: proc(addr: u32) -> u8 {
    return mem[addr]
}

bus9_write_wram :: proc(addr: u32, value: u8) {
    mem[addr] = value
}

bus9_read_mram :: proc(addr: u32) -> u8 {
    return mem[addr]
}

bus9_write_mram :: proc(addr: u32, value: u8) {
    mem[addr] = value
}

bus9_dtcm_inside :: proc(addr: u32) -> bool {
    base := dtcmsize.base << 12
    return (addr >= base) && (addr < (base + (512 << dtcmsize.vsize)))
}

bus9_get_vramstat :: proc() -> u8 {
    bit0 := u8(vramcnt[2].enable && vramcnt[2].mst == 2)
    bit1 := u8(vramcnt[3].enable && vramcnt[3].mst == 2)
    return bit0 | (bit1 << 1)
}

bus9_get_vram :: proc(addr: u32) -> u8 {
    if(vramcnt[2].enable) {
        offset := (u32(vramcnt[2].offset & 1) * 0x20000)
        base := 0x6800000 + offset
        address := addr + 0x840000 - offset
        if(address > base && address < base + 0x20000) {
            return mem[address]
        }
    }
    if(vramcnt[3].enable) {
        offset := (u32(vramcnt[3].offset & 1) * 0x20000)
        base := 0x6800000 + offset
        address := addr + 0x860000 - offset
        if(address > base && address < base + 0x20000) {
            return mem[address]
        }
    }
    return 0
}