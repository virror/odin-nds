package main

import "core:fmt"

@(private="file")
romctrl: u32
@(private="file")
auxspicnt: u16
@(private="file")
command: [8]u8

cart_read :: proc() {

}

cart_write8 :: proc(addr: u32, value: u8, arm7: bool) {
    if(bool((exmemcnt >> 11) & 1) == arm7) {
        switch(addr) {
        case 0x40001A1:
            auxspicnt &= 0x00FF
            auxspicnt |= (u16(value) << 8)
            fmt.printfln("auxspicnt %X", auxspicnt)
        case 0x40001A8:
            command[0] = value
            fmt.printfln("Command %X", value)
        case 0x40001A9:
            command[1] = value
        case 0x40001AA:
            command[2] = value
        case 0x40001AB:
            command[3] = value
        case 0x40001AC:
            command[4] = value
        case 0x40001AD:
            command[5] = value
        case 0x40001AE:
            command[6] = value
        case 0x40001AF:
            command[7] = value
            fmt.println(bus9_get32(IO_IE))
            bus7_irq_set(19)
        case:
            fmt.printfln("Cart write 8 %X %X %d", addr, value, arm7)
        }
    }
}

cart_write32 :: proc(addr: u32, value: u32, arm7: bool) {
    if(bool((exmemcnt >> 11) & 1) == arm7) {
        switch(addr) {
        case 0x40001A0:
            auxspicnt = u16(value)
            fmt.println("Handle write to AUXSPIDATA")
        case 0x40001A4:
            romctrl = value
            fmt.printfln("ROMCTRL %X", value)
        case:
            fmt.printfln("Cart write 32 %X %X %d", addr, value, arm7)
        }
    }
}

//  19    NDS-Slot Game Card Data Transfer Completion
//  20    NDS-Slot Game Card IREQ_MC