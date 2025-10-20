package main

import "core:fmt"
import "core:math"
import "core:math/big"

sqrtcntl: u8
sqrtres: u32
sqrtval: u64

bus_math_write :: proc(addr: u32, value: u8) {
    switch(addr) {
    case 0x40002B0:
        sqrtcntl = value
        bus_math_sqr()
    case 0x40002B8:
        sqrtval = (sqrtval & 0xFFFFFFFFFFFFFF00) | u64(value) << 0
    case 0x40002B9:
        sqrtval = (sqrtval & 0xFFFFFFFFFFFF00FF) | u64(value) << 8
    case 0x40002BA:
        sqrtval = (sqrtval & 0xFFFFFFFFFF00FFFF) | u64(value) << 16
    case 0x40002BB:
        sqrtval = (sqrtval & 0xFFFFFFFF00FFFFFF) | u64(value) << 24
        bus_math_sqr()
    case 0x40002BC:
        sqrtval = (sqrtval & 0xFFFFFF00FFFFFFFF) | u64(value) << 32
    case 0x40002BD:
        sqrtval = (sqrtval & 0xFFFF00FFFFFFFFFF) | u64(value) << 40
    case 0x40002BE:
        sqrtval = (sqrtval & 0xFF00FFFFFFFFFFFF) | u64(value) << 48
    case 0x40002BF:
        sqrtval = (sqrtval & 0x00FFFFFFFFFFFFFF) | u64(value) << 56
        bus_math_sqr()
    }
}

bus_math_read :: proc(addr: u32) -> u8 {
    switch(addr) {
    case 0x40002B4:
        return u8((sqrtres >> 0) & 0xFF)
    case 0x40002B5:
        return u8((sqrtres >> 8) & 0xFF)
    case 0x40002B6:
        return u8((sqrtres >> 16) & 0xFF)
    case 0x40002B7:
        return u8((sqrtres >> 24) & 0xFF)
    }
    return 0
}

bus_math_sqr :: proc() {
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