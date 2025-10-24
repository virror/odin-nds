package main

import "core:fmt"
import sdl "vendor:sdl3"
import sdlttf "vendor:sdl3/ttf"
import "../../odin-libs/cpu/arm7"
import "../../odin-libs/cpu/arm9"
when(DEBUG) {
font: ^sdlttf.Font

debug_init :: proc() {
    font = sdlttf.OpenFont("SpaceMono-Regular.ttf", 18)
}

debug_draw :: proc() {
    cpsr := arm7.get_cpsr()
    debug_draw_reg("PC  ", arm7.reg_get(arm7.Regs.PC), 10, 10)
    debug_draw_reg("R0  ", arm9.reg_get(arm9.Regs.R0), 180, 10)
    debug_draw_reg("R1  ", arm9.reg_get(arm9.Regs.R1), 10, 35)
    debug_draw_reg("R2  ", arm9.reg_get(arm9.Regs.R2), 180, 35)
    debug_draw_reg("R3  ", arm9.reg_get(arm9.Regs.R3), 10, 60)
    debug_draw_reg("R4  ", arm9.reg_get(arm9.Regs.R4), 180, 60)
    debug_draw_reg("R5  ", arm9.reg_get(arm9.Regs.R5), 10, 85)
    debug_draw_reg("R6  ", arm9.reg_get(arm9.Regs.R6), 180, 85)
    debug_draw_reg("R7  ", arm9.reg_get(arm9.Regs.R7), 10, 110)
    debug_draw_reg("R8  ", arm9.reg_get(arm9.Regs.R8), 180, 110)
    debug_draw_reg("R9  ", arm9.reg_get(arm9.Regs.R9), 10, 135)
    debug_draw_reg("R10 ", arm9.reg_get(arm9.Regs.R10), 180, 135)
    debug_draw_reg("R11 ", arm9.reg_get(arm9.Regs.R11), 10, 160)
    debug_draw_reg("R12 ", arm9.reg_get(arm9.Regs.R12), 180, 160)

    debug_draw_reg2("SP(R13)  ", arm9.reg_raw(arm9.Regs.SP, arm9.Modes.M_USER), 10, 210, arm9.Modes.M_USER)
    debug_draw_reg2("SP_fiq   ", arm9.reg_raw(arm9.Regs.SP, arm9.Modes.M_FIQ), 240, 210, arm9.Modes.M_FIQ)
    debug_draw_reg2("SP_svc   ", arm9.reg_raw(arm9.Regs.SP, arm9.Modes.M_SUPERVISOR), 10, 235, arm9.Modes.M_SUPERVISOR)
    debug_draw_reg2("SP_abt   ", arm9.reg_raw(arm9.Regs.SP, arm9.Modes.M_ABORT), 240, 235, arm9.Modes.M_ABORT)
    debug_draw_reg2("SP_irq   ", arm9.reg_raw(arm9.Regs.SP, arm9.Modes.M_IRQ), 10, 260, arm9.Modes.M_IRQ)
    debug_draw_reg2("SP_und   ", arm9.reg_raw(arm9.Regs.SP, arm9.Modes.M_UNDEFINED), 240, 260, arm9.Modes.M_UNDEFINED)

    debug_draw_reg2("LR(R14)  ", arm9.reg_raw(arm9.Regs.LR, arm9.Modes.M_USER), 10, 285, arm9.Modes.M_USER)
    debug_draw_reg2("LR_fiq   ", arm9.reg_raw(arm9.Regs.LR, arm9.Modes.M_FIQ), 240, 285, arm9.Modes.M_FIQ)
    debug_draw_reg2("LR_svc   ", arm9.reg_raw(arm9.Regs.LR, arm9.Modes.M_SUPERVISOR), 10, 310, arm9.Modes.M_SUPERVISOR)
    debug_draw_reg2("LR_abt   ", arm9.reg_raw(arm9.Regs.LR, arm9.Modes.M_ABORT), 240, 310, arm9.Modes.M_ABORT)
    debug_draw_reg2("LR_irq   ", arm9.reg_raw(arm9.Regs.LR, arm9.Modes.M_IRQ), 10, 335, arm9.Modes.M_IRQ)
    debug_draw_reg2("LR_und   ", arm9.reg_raw(arm9.Regs.LR, arm9.Modes.M_UNDEFINED), 240, 335, arm9.Modes.M_UNDEFINED)

    debug_draw_reg("CPSR     ", u32(cpsr), 10, 360)
    debug_draw_reg2("SPSR_fiq ", arm9.reg_raw(arm9.Regs.SPSR, arm9.Modes.M_FIQ), 240, 360, arm9.Modes.M_FIQ)
    debug_draw_reg2("SPSR_svc ", arm9.reg_raw(arm9.Regs.SPSR, arm9.Modes.M_SUPERVISOR), 10, 385, arm9.Modes.M_SUPERVISOR)
    debug_draw_reg2("SPSR_abt ", arm9.reg_raw(arm9.Regs.SPSR, arm9.Modes.M_ABORT), 240, 385, arm9.Modes.M_ABORT)
    debug_draw_reg2("SPSR_irq ", arm9.reg_raw(arm9.Regs.SPSR, arm9.Modes.M_IRQ), 10, 410, arm9.Modes.M_IRQ)
    debug_draw_reg2("SPSR_und ", arm9.reg_raw(arm9.Regs.SPSR, arm9.Modes.M_UNDEFINED), 240, 410, arm9.Modes.M_UNDEFINED)

    debug_draw_flag("N    ", 31, 350, 10)
    debug_draw_flag("Z    ", 30, 350, 35)
    debug_draw_flag("C    ", 29, 350, 60)
    debug_draw_flag("V    ", 28, 350, 85)
    debug_draw_flag("!IRQ ", 7, 350, 110)
    debug_draw_flag("!FIQ ", 6, 350, 135)

    state :cstring= cpsr.Thumb ? "THUMB" : "ARM"
    line0 := fmt.caprintf("%s %s", "State: ", state)
    debug_text(line0, 350, 160, {230, 230, 230, 230})

    mode := cpsr.Mode
    mode_name: cstring
    switch(mode) {
    case arm7.Modes.M_USER:
        mode_name = "User"
        break
    case arm7.Modes.M_FIQ:
        mode_name = "FIQ"
        break
    case arm7.Modes.M_IRQ:
        mode_name = "IRQ"
        break
    case arm7.Modes.M_SUPERVISOR:
        mode_name = "Supervisor"
        break
    case arm7.Modes.M_ABORT:
        mode_name = "Abort"
        break
    case arm7.Modes.M_UNDEFINED:
        mode_name = "Undefined"
        break
    case arm7.Modes.M_SYSTEM:
        mode_name = "System"
        break
    case:
        mode_name = "Error!"
    }
    line := fmt.caprintf("Mode: %s", mode_name)
    debug_text(line, 10, 185, {230, 230, 230, 230})

    if(cpsr.Thumb) { //THUMB
        debug_draw_op_thumb("->", 0, 10, 510)
        debug_draw_op_thumb("  ", 1, 10, 535)
    } else {
        debug_draw_op_arm("->", 0, 10, 510)
        debug_draw_op_arm("  ", 1, 10, 535)
    }
}

debug_draw_op_arm :: proc(opText: cstring, pc: u32, posX: f32, posY: f32) {
    op := arm9.get_instruction(pc)
    name, suffix := debug_get_arm_names(op)
    line := fmt.caprintf("%s %8x %s %s", opText, op, name, suffix)
    debug_text(line, posX, posY, {230, 230, 230, 230})
}

debug_draw_op_thumb :: proc(opText: cstring, pc: u32, posX: f32, posY: f32) {
    op := u16(arm7.get_instruction(pc))
    name := debug_get_thumb_names(op)
    line := fmt.caprintf("%s %4x %s", opText, op, name)
    debug_text(line, posX, posY, {230, 230, 230, 230})
}

debug_draw_reg :: proc(regText: cstring, reg: u32, posX: f32, posY: f32) {
    line := fmt.caprintf("%s %8x", regText, reg)
    debug_text(line, posX, posY, {230, 230, 230, 230})
}

debug_draw_reg2 :: proc(regText: cstring, reg: u32, posX: f32, posY: f32, mode: arm9.Modes) {
    current_mode := arm9.get_cpsr().Mode
    if(current_mode == arm9.Modes.M_USER) {
        current_mode = arm9.Modes.M_SYSTEM
    }
    line := fmt.caprintf("%s %8x", regText, reg)
    if(current_mode == mode) {
        debug_text(line, posX, posY, {230, 230, 230, 230})
    } else {
        debug_text(line, posX, posY, {130, 130, 130, 230})
    }
}

debug_draw_flag :: proc(flagText: cstring, flag: u8, posX: f32, posY: f32) {
    cpsr := arm9.get_cpsr()
    line := fmt.caprintf("%s %s", flagText, utils_bit_get32(u32(cpsr), flag)?"true":"false")
    debug_text(line, posX, posY, {230, 230, 230, 230})
}

debug_quit :: proc() {
    sdlttf.CloseFont(font)
}

debug_text :: proc(text: cstring, posX: f32, posY: f32, color: sdl.Color) {
    surface := sdlttf.RenderText_Solid(font, text, len(text), color)
    texture := sdl.CreateTextureFromSurface(debug_render, surface)
    
    texW :f32= 0
    texH :f32= 0
    sdl.GetTextureSize(texture, &texW, &texH)
    
    text_rect: sdl.FRect
    text_rect.x = posX
    text_rect.y = posY
    text_rect.w = texW
    text_rect.h = texH
    
    sdl.RenderTexture(debug_render, texture, nil, &text_rect)
    sdl.DestroySurface(surface)
    sdl.DestroyTexture(texture)
}

debug_get_arm_names :: proc(opcode: u32) -> (cstring, cstring){
    //4 uppermost bits are conditional, if they match, execute, otherwise return
    cond := opcode & 0xF0000000
    suffix: cstring
    switch(cond) {
    case 0x00000000: //Z set
        suffix = "EQ"
        break
    case 0x10000000: //Z clear
        suffix = "NE"
        break
    case 0x20000000: //C set
        suffix = "CS"
        break
    case 0x30000000: //C clear
        suffix = "CC"
        break
    case 0x40000000: //N set
        suffix = "MI"
        break
    case 0x50000000: //N clear
        suffix = "PL"
        break
    case 0x60000000: //V set
        suffix = "VS"
        break
    case 0x70000000: //V clear
        suffix = "VC"
        break
    case 0x80000000: //C set and Z clear
        suffix = "HI"
        break
    case 0x90000000: //C clear and Z set
        suffix = "LS"
        break
    case 0xA0000000: //N == V
        suffix = "GE"
        break
    case 0xB0000000: //N != V
        suffix = "LT"
        break
    case 0xC0000000: //Z clear and (N == V)
        suffix = "GT"
        break
    case 0xD0000000: //Z set or (N != V)
        suffix = "LE"
        break
    }

    id := opcode & 0xE000000
    op_name :cstring= "Undefined"
    //fmt.println(id)
    switch(id) {
    case 0x0000000:
    {
        if((opcode & 0xFFFFFC0) == 0x12FFF00) {
            op_name = dbg_bx(opcode)
        } else if((opcode & 0x10000F0) == 0x0000090) { //MUL, MLA
            if((opcode & 0x00000F0) == 0x0000090) {
                if(utils_bit_get32(opcode, 23)) { //MULL, MLAL
                    op_name = dbg_mull_mlal(opcode)
                } else {
                    op_name = dbg_mul_mla(opcode)
                }
            }
        } else if ((opcode & 0x10000F0) == 0x1000090) {
            op_name = dbg_swap(opcode)
        } else if (((opcode & 0xF0) == 0xB0) || ((opcode & 0xD0) == 0xD0)){
            op_name = dbg_hw_transfer(opcode)
        } else { //ALU reg
            op_name = dbg_alu(opcode, false)
        }
        break
    }
    case 0x1000000:
        if((opcode & 0xFFF0FF0) == 0x16F0F10) {
            op_name = dbg_clz(opcode)
        } else {
            op_name = dbg_qaddsub(opcode)
        }
        break
    case 0x2000000: //ALU immediate
        op_name = dbg_alu(opcode, true)
        break
    case 0x4000000: //LDR, STR immediate
        op_name = dbg_ldr(opcode, false)
        break
    case 0x6000000: //LDR, STR register
        op_name = dbg_ldr(opcode, true)
        break
    case 0x8000000: //LDM, STM (PUSH, POP)
        op_name = dbg_ldm_stm(opcode)
        break
    case 0xA000000: //B, BL, BLX
        if(cond == 0xF0000000) { //BLX immediate
            op_name = dbg_blx(opcode)
        } else {
            op_name = dbg_branch(opcode)
        }
        break
    case 0xE000000: //SWI
        if(utils_bit_get32(opcode, 24)) {
            op_name = "SWI"
        } else {
            if(utils_bit_get32(opcode, 4)) {
                op_name = dbg_mrc_mcr(opcode)
            } else {
                op_name = dbg_cdp(opcode)
            }
        }
        break
    }
    return op_name, suffix
}

debug_get_thumb_names :: proc(opcode: u16) -> cstring {
    id := opcode & 0xF800
    op_name :cstring= "Undefined"
    switch(id) {
    case 0x0000,
         0x0800,
         0x1000:
        op_name = shift(opcode)
        break
    case 0x1800:
        op_name = add_sub(opcode) // Add, sub
        break
    case 0x2000, //Move, compare
         0x2800, //add, substract
         0x3000, //add, substract
         0x3800: //add, substract
        op_name = mcas_imm(opcode)
        break
    case 0x4000:
        if(utils_bit_get16(opcode, 10)) {
            op_name = hi_reg(opcode)
        } else {
            op_name = alu(opcode)
        }
        break
    case 0x4800:
        op_name = ld_pc(opcode)
        break
    case 0x5000,
            0x5800:
        if(utils_bit_get16(opcode, 9)) {
            op_name = ls_ext(opcode)
        } else {
            op_name = ls_reg(opcode)
        }
        break
    case 0x6000,
         0x6800,
         0x7000,
         0x7800:
        op_name = ls_imm(opcode)
        break
    case 0x8000,
         0x8800:
        op_name = ls_hw(opcode)
        break
    case 0x9000,
         0x9800:
        op_name = ls_sp(opcode)
        break
    case 0xA000,
         0xA800:
        op_name = ld(opcode)
        break
    case 0xB000,
         0xB800:
        if(utils_bit_get16(opcode, 10)) {
            op_name = push_pop(opcode)
        } else {
            op_name = sp_ofs(opcode)
        }
        break
    case 0xC000,
         0xC800:
        op_name = ls_mp(opcode)
        break
    case 0xD000,
         0xD800:
        op_name = b_cond(opcode)
        break
    case 0xE000:
        op_name = b_uncond(opcode)
        break
    case 0xF000,
         0xF800:
        op_name = bl(opcode)
        break
    }
    return op_name
}
} else {
    debug_draw :: proc() {}
}