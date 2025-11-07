package main

import "core:fmt"
import "core:time"
import "core:time/datetime"
import "core:time/timezone"

@(private="file")
Clock :: bit_field u8 {
    data: u8        | 1,
    clock: bool     | 1,
    select: bool    | 1,
    data_dir: bool  | 1,
    clock_dir: bool | 1,
    sel_dir: u8     | 1,
    na: u8          | 2,
}

@(private="file")
Mode :: enum {
    Command,
    Read,
    Write,
    Done,
}

DateTime :: struct {
    year: u8,
    month: u8,
    day: u8,
    weekday: u8,
    hour: u8,
    minute: u8,
    second: u8,
}

@(private="file")
state: u8
@(private="file")
data: u8
@(private="file")
mode: Mode
@(private="file")
command: u8
@(private="file")
status1: u8 = 128
@(private="file")
status2: u8
@(private="file")
date_time: DateTime
@(private="file")
alarm1: DateTime
@(private="file")
alarm2: DateTime
@(private="file")
adjust: u8
@(private="file")
free: u8
@(private="file")
data_out: u8
@(private="file")
time_zone: ^datetime.TZ_Region
@(private="file")
params: [8]u8 = {1, 1, 7, 3, 3, 3, 1, 1}
@(private="file")
param: u8

//TODO: Handle IRQs
//TODO: Handle 12/24h time
rtc_init :: proc() {
    time_zone, _ = timezone.region_load("local")
}

rtc_write :: proc(value: u8) {
    val := Clock(value)
    if(mode == .Done) {
        if(params[command] > (param + 1)) {
            param += 1
            rtc_set_data_out()
            mode = .Read
        } else {
            mode = .Command
            param = 0
        }
        state = 0
        return
    }
    if(val.clock) {
        if(val.clock_dir) {
            switch(state) {
            case 0: //Init transfer
                if(val.select) {
                    state = 1
                } else {
                    state = 0
                }
            case 1:
                data |= val.data << 7
                state += 1
            case 2:
                data |= val.data << 6
                state += 1
            case 3:
                data |= val.data << 5
                state += 1
            case 4:
                data |= val.data << 4
                state += 1
            case 5:
                data |= val.data << 3
                state += 1
            case 6:
                data |= val.data << 2
                state += 1
            case 7:
                data |= val.data << 1
                state += 1
            case 8:
                data |= val.data
                if(mode == .Command) {
                    command = (data >> 1) & 7
                    if(bool(data & 1)) {
                        mode = .Read
                        state = 0
                        rtc_set_data_out()
                    } else {
                        mode = .Write
                        state = 1
                    }
                } else if(mode == .Write) {
                    switch(command) {
                    case 0:
                        if(bool(data & 1)) {
                            status1 = 0
                        } else {
                            status1 &= 0xF0
                            status1 |= (data & 0x0F)
                        }
                    case 1:
                        status2 = data
                        //TODO: Handle setting of Frequency Steady Interrupt Register
                    case 2:
                        rtc_set_datetime(param, data)
                    case 3:
                        rtc_set_time(param, data)
                    case 4:
                        rtc_set_alarm(param, data, true)
                    case 5:
                        rtc_set_alarm(param, data, false)
                    case 6:
                        adjust = data
                    case 7:
                        free = data
                    }
                    param += 1
                    if(params[command]) == param {
                        mode = .Done
                    } else {
                        state = 1
                    }
                }
                data = 0
            }
        } else {

        }
    }
}

rtc_read :: proc() -> u8 {
    bit := (data_out >> state) & 1
    state += 1
    if(state == 8) {
        mode = .Done
    }
    return bit
}

@(private="file")
rtc_get_time :: proc(param: u8) -> u8 {
    switch(param) {
    case 0:
        if(bool((status1 >> 1) & 1)) {
            val := date_time.hour
            if(date_time.hour > 0x11) {
                val |= 0x40
            }
            return val
        } else {
            return date_time.hour
        }
    case 1:
        return date_time.minute
    case 2:
        return date_time.second
    }
    return 0
}

@(private="file")
rtc_get_datetime :: proc(param: u8) -> u8 {
    switch(param) {
    case 0:
        return date_time.year
    case 1:
        return date_time.month
    case 2:
        return date_time.day
    case 3:
        return date_time.weekday
    case 4:
        return date_time.hour
    case 5:
        return date_time.minute
    case 6:
        return date_time.second
    }
    return 0
}

@(private="file")
rtc_get_alarm :: proc(param: u8, is_1: bool) -> u8 {
    if(is_1) {
        switch(param) {
        case 0:
            return alarm1.weekday
        case 1:
            return alarm1.hour
        case 2:
            return alarm1.minute
        }
    } else {
        switch(param) {
        case 0:
            return alarm2.weekday
        case 1:
            return alarm2.hour
        case 2:
            return alarm2.minute
        }
    }
    return 0
}

@(private="file")
rtc_set_time :: proc(param: u8, data: u8) {
    switch(param) {
    case 0:
        date_time.minute = data
    case 1:
        date_time.minute = data
    case 2:
        date_time.second = data
    }
}

@(private="file")
rtc_set_datetime :: proc(param: u8, data: u8) {
    switch(param) {
    case 0:
        date_time.year = data
    case 1:
        date_time.month = data
    case 2:
        date_time.day = data
    case 3:
        date_time.weekday = data
    case 4:
        date_time.hour = data
    case 5:
        date_time.minute = data
    case 6:
        date_time.second = data
    }
}

@(private="file")
rtc_set_alarm :: proc(param: u8, data: u8, is_1: bool) {
    if(is_1) {
        switch(param) {
        case 0:
            alarm1.weekday = data
        case 1:
            alarm1.hour = data
        case 2:
            alarm1.minute = data
        }
    } else {
        switch(param) {
        case 0:
            alarm2.weekday = data
        case 1:
            alarm2.hour = data
        case 2:
            alarm2.minute = data
        }
    }
}

rtc_set_data_out :: proc() {
    switch(command) {
    case 0:
        data_out = status1
        status1 &= 0x0F
    case 1:
        data_out = status2
    case 2:
        rtc_generate_datetime()
        data_out = rtc_get_datetime(param)
    case 3:
        rtc_generate_datetime()
        data_out = rtc_get_time(param)
    case 4:
        data_out = rtc_get_alarm(param, true)
    case 5:
        data_out = rtc_get_alarm(param, false)
    case 6:
        data_out = adjust
    case 7:
        data_out = free
    }
}

@(private="file")
rtc_generate_datetime :: proc() {
    ts := time.now()
    dt, _ := time.time_to_datetime(ts)
    dt = timezone.datetime_to_tz(dt, time_zone)
    date_time.day = rtc_to_bcd(u8(dt.day))
    date_time.hour = rtc_to_bcd(u8(dt.hour))
    date_time.minute = rtc_to_bcd(u8(dt.minute))
    date_time.month = rtc_to_bcd(u8(dt.month))
    date_time.second = rtc_to_bcd(u8(dt.second))
    date_time.year = rtc_to_bcd(u8(dt.year - 2000))
    date, _ := datetime.date_to_ordinal(dt.date)
    date_time.weekday = rtc_to_bcd(u8(datetime.day_of_week(date)))
}

@(private="file")
rtc_to_bcd :: proc(data: u8) -> u8 {
    ret_val := data % 10
    ret_val |= ((data / 10) % 10) << 4
    return ret_val
}