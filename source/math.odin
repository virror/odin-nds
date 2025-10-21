package main

import "core:fmt"
import "core:math"
import "core:math/big"

divcnt: u16
divnum: u64
divden: u64
divres: u64
divrem: u64
sqrtcnt: u16
sqrtres: u32
sqrtval: u64

math_write16 :: proc(addr: u32, value: u16) {
    switch(addr) {
    case 0x40002B0:
        sqrtcnt = value
        math_sqr()
    case 0x4000280:
        divcnt = value
        math_div()
    }
}

math_write32 :: proc(addr: u32, value: u32) {
    switch(addr) {
    case 0x4000290:
        divnum = (divnum & 0xFFFFFFFF00000000) | u64(value)
        math_div()
    case 0x4000294:
        divnum = (divnum & 0x00000000FFFFFFFF) | (u64(value) << 32)
        math_div()
    case 0x4000298:
        divden = (divden & 0xFFFFFFFF00000000) | u64(value)
        math_div()
    case 0x400029C:
        divden = (divden & 0x00000000FFFFFFFF) | (u64(value) << 32)
        math_div()
    case 0x40002B8:
        sqrtval = (sqrtval & 0xFFFFFFFF00000000) | u64(value)
        math_sqr()
    case 0x40002BC:
        sqrtval = (sqrtval & 0x00000000FFFFFFFF) | (u64(value) << 32)
        math_sqr()
    }
}

math_read16 :: proc(addr: u32) -> u16 {
    switch(addr) {
    case 0x40002B0:
        return sqrtcnt
    case 0x4000280:
        return divcnt
    }
    return 0
}

math_read32 :: proc(addr: u32) -> u32 {
    switch(addr) {
    case 0x40002A0:
        return u32(divres)
    case 0x40002A4:
        return u32(divres >> 32)
    case 0x40002A8:
        return u32(divrem)
    case 0x40002AC:
        return u32(divrem >> 32)
    case 0x40002B4:
        return sqrtres
    }
    return 0
}

math_sqr :: proc() {
    if(bool(sqrtcnt & 0x1)) {
        value: big.Int
        result: big.Int
        big.int_set_from_integer(&value, sqrtval)
        big.sqrt(&result, &value)
        sqrtres, _ = big.int_get_u32(&result)
        big.destroy(&value)
        big.destroy(&result)
    } else {
        sqrtres = u32(math.sqrt(f64(u32(sqrtval))))
    }
}

math_div :: proc() {
    mode := divcnt & 3
    divcnt = utils_bit_clear16(divcnt, 14)
    switch(mode) {
    case 0:
        if(i32(divden) == 0) {
            if(i32(divnum) >= 0) {
                divres = 0xFFFFFFFF
                divrem = divnum
            } else {
                divres = 0xFFFFFFFF00000000 | 1
                divrem = 0xFFFFFFFF00000000 | divnum
            }
            if(divden == 0) {
                divcnt = utils_bit_set16(divcnt, 14)
            }
            return
        }
        if(divnum == 0x80000000 && i32(divden) == -1) {    //Overflow
            divres = 0x80000000
            divrem = 0
            return
        }
        divres = u64(i32(divnum) / i32(divden))
        divrem = u64(i32(divnum) % i32(divden))
    case 1:
        if(i32(divden) == 0) {
            if(i64(divnum) >= 0) {
                divres = 0xFFFFFFFFFFFFFFFF
                divrem = divnum
            } else {
                divres = 1
                divrem = divnum
            }
            if(divden == 0) {
                divcnt = utils_bit_set16(divcnt, 14)
            }
            return
        }
        if(divnum == 0x8000000000000000 && i32(divden) == -1) {    //Overflow
            divres = 0x8000000000000000
            divrem = 0
            return
        }
        divres = u64(i64(divnum) / i64(i32(divden)))
        divrem = u64(i64(divnum) % i64(i32(divden)))
    case 2:
        if(divden == 0) {
            if(i64(divnum) >= 0) {
                divres = 0xFFFFFFFFFFFFFFFF
                divrem = divnum
            } else {
                divres = 1
                divrem = divnum
            }
            if(divden == 0) {
                divcnt = utils_bit_set16(divcnt, 14)
            }
            return
        }
        if(divnum == 0x8000000000000000 && i64(divden) == -1) {    //Overflow
            divres = 0x8000000000000000
            divrem = 0
            return
        }
        divres = u64(i64(divnum) / i64(divden))
        divrem = u64(i64(divnum) % i64(divden))
    }
}