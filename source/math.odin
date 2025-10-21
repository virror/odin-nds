package main

import "core:fmt"
import "core:math"
import "core:math/big"

sqrtcntl: u16
sqrtres: u32
sqrtval: u64

math_write16 :: proc(addr: u32, value: u16) {
    switch(addr) {
    case 0x40002B0:
        sqrtcntl = value
        math_sqr()
    }
}

math_write32 :: proc(addr: u32, value: u32) {
    switch(addr) {
    case 0x40002B8:
        sqrtval = u64(value)
        math_sqr()
    case 0x40002BC:
        sqrtval = (sqrtval & 0x00000000FFFFFFFF) | (u64(value) << 32)
        math_sqr()
    }
}

math_read16 :: proc(addr: u32) -> u16 {
    switch(addr) {
    case 0x40002B0:
        return sqrtcntl
    }
    return 0
}

math_read32 :: proc(addr: u32) -> u32 {
    switch(addr) {
    case 0x40002B4:
        return sqrtres
    }
    return 0
}

math_sqr :: proc() {
    if (bool(sqrtcntl & 0x1)) {
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