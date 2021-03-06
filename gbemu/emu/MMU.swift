//
//  MMU.swift
//  gbemu
//
//  Created by Otis Carpay on 10/08/15.
//  Copyright © 2015 Otis Carpay. All rights reserved.
//

import Swift

final class MMU {
    var isInBios = true
    
    struct InterruptByte: OptionSet {
        let rawValue: Byte
        static let vBlank  = InterruptByte(rawValue: 0x01)
        static let lcdStat = InterruptByte(rawValue: 0x02)
        static let timer   = InterruptByte(rawValue: 0x04)
        static let serial  = InterruptByte(rawValue: 0x08) //Not implemented
        static let joypad  = InterruptByte(rawValue: 0x10)
    }
    
    private var bios: [Byte] = [
        0x31, 0xFE, 0xFF, 0xAF, 0x21, 0xFF, 0x9F, 0x32, 0xCB, 0x7C, 0x20, 0xFB, 0x21, 0x26, 0xFF, 0x0E,
        0x11, 0x3E, 0x80, 0x32, 0xE2, 0x0C, 0x3E, 0xF3, 0xE2, 0x32, 0x3E, 0x77, 0x77, 0x3E, 0xFC, 0xE0,
        0x47, 0x11, 0x04, 0x01, 0x21, 0x10, 0x80, 0x1A, 0xCD, 0x95, 0x00, 0xCD, 0x96, 0x00, 0x13, 0x7B,
        0xFE, 0x34, 0x20, 0xF3, 0x11, 0xD8, 0x00, 0x06, 0x08, 0x1A, 0x13, 0x22, 0x23, 0x05, 0x20, 0xF9,
        0x3E, 0x19, 0xEA, 0x10, 0x99, 0x21, 0x2F, 0x99, 0x0E, 0x0C, 0x3D, 0x28, 0x08, 0x32, 0x0D, 0x20,
        0xF9, 0x2E, 0x0F, 0x18, 0xF3, 0x67, 0x3E, 0x64, 0x57, 0xE0, 0x42, 0x3E, 0x91, 0xE0, 0x40, 0x04,
        0x1E, 0x02, 0x0E, 0x0C, 0xF0, 0x44, 0xFE, 0x90, 0x20, 0xFA, 0x0D, 0x20, 0xF7, 0x1D, 0x20, 0xF2,
        0x0E, 0x13, 0x24, 0x7C, 0x1E, 0x83, 0xFE, 0x62, 0x28, 0x06, 0x1E, 0xC1, 0xFE, 0x64, 0x20, 0x06,
        0x7B, 0xE2, 0x0C, 0x3E, 0x87, 0xE2, 0xF0, 0x42, 0x90, 0xE0, 0x42, 0x15, 0x20, 0xD2, 0x05, 0x20,
        0x4F, 0x16, 0x20, 0x18, 0xCB, 0x4F, 0x06, 0x04, 0xC5, 0xCB, 0x11, 0x17, 0xC1, 0xCB, 0x11, 0x17,
        0x05, 0x20, 0xF5, 0x22, 0x23, 0x22, 0x23, 0xC9, 0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B,
        0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D, 0x00, 0x08, 0x11, 0x1F, 0x88, 0x89, 0x00, 0x0E,
        0xDC, 0xCC, 0x6E, 0xE6, 0xDD, 0xDD, 0xD9, 0x99, 0xBB, 0xBB, 0x67, 0x63, 0x6E, 0x0E, 0xEC, 0xCC,
        0xDD, 0xDC, 0x99, 0x9F, 0xBB, 0xB9, 0x33, 0x3E, 0x3C, 0x42, 0xB9, 0xA5, 0xB9, 0xA5, 0x42, 0x3C,
        0x21, 0x04, 0x01, 0x11, 0xA8, 0x00, 0x1A, 0x13, 0xBE, 0x20, 0xFE, 0x23, 0x7D, 0xFE, 0x34, 0x20,
        0xF5, 0x06, 0x19, 0x78, 0x86, 0x23, 0x05, 0x20, 0xFB, 0x86, 0x20, 0xFE, 0x3E, 0x01, 0xE0, 0x50
    ]
//    private var cartridge = Cartridge(data: [Byte](repeating: 0, count: 0x8000))
    var cartridge = Cartridge(data: [Byte](repeating: 0, count: 0x8000))
    private var wram = [Byte](repeating: 0xFF, count: 0x2000)
    private var zram = [Byte](repeating: 0xFF, count:   0x80) // TODO zram -> hram?
    var iEnable: InterruptByte = []
    var iFlag: InterruptByte = []
    
    let system: Gameboy
    var timer: Timer
    
    init(system: Gameboy) {
        self.system = system
        timer = Timer(system: system)
    }
    
    func readByte(_ address: UInt16) -> Byte {
        let addressWord = address
        let address = Int(address)
        
        if isInBios && addressWord < 0x100 {
            return bios[address]
        }
        
        switch (addressWord) {
            case 0x0000 ..< 0x8000: return cartridge.readROM(address)
            
            case 0x8000 ..< 0xA000: return system.gpu.vram[address & 0x1FFF]
            
            case 0xA000 ..< 0xC000: return cartridge.readRAM(address & 0x1FFF)
            
            case 0xC000 ..< 0xE000: return wram[address & 0x1FFF]
            case 0xE000 ..< 0xFE00: return wram[address & 0x1FFF]
            case 0xFE00 ..< 0xFEA0: return system.gpu.oam[address & 0xFF]
            case 0xFEA0 ..< 0xFF00: return 0
            
            case 0xFF00: return system.joypad.readByte()
            case 0xFF01,
                 0xFF02: return 0 // Serial not implemented
            case 0xFF03: fatalError()
            
            case 0xFF04 ..< 0xFF08: return timer.readByte(address)
            
            case 0xFF0F: return iFlag.rawValue
            case 0xFFFF: return iEnable.rawValue
            
            case 0xFF10 ..< 0xFF40: return system.apu.readByte(address)
            case 0xFF40 ..< 0xFF80: return system.gpu.readByte(address)
            
            case 0xFF80 ..< 0xFFFF: return zram[address & 0x7F]
            default:
                print("Address not implemented (read): " + String(format: "%04X", address))
                return 0
        }
    }
    
    func readWord(_ address: UInt16) -> Word {
        return Word(readByte(address)) | (Word(readByte(address &+ 1)) << 8)
    }
    
    func writeByte(_ address: UInt16, value: Byte) {
        let addressWord = address
        let address = Int(address)
        
        switch (addressWord) {
            case 0x0000 ..< 0x8000: cartridge.writeROM(address, value: value)
            
            case 0x8000 ..< 0xA000:
                system.gpu.vram[address & 0x1FFF] = value;
                system.gpu.updateTile(addressWord, value: value) //TODO fix
            
            case 0xA000 ..< 0xC000: cartridge.writeRAM(address & 0x1FFF, value: value)
            
            case 0xC000 ..< 0xE000: wram[address & 0x1FFF] = value
            case 0xE000 ..< 0xFE00: wram[address & 0x1FFF] = value
            case 0xFE00 ..< 0xFEA0: system.gpu.oam[address & 0xFF] = value
            case 0xFEA0 ..< 0xFF00: break
            
            case 0xFF00: system.joypad.writeByte(value)
            case 0xFF01,
                 0xFF02: break // Serial not implemented
            case 0xFF04 ..< 0xFF08: timer.writeByte(address, value: value)
            
            case 0xFF10 ..< 0xFF40: system.apu.writeByte(address, value: value)
            case 0xFF40 ..< 0xFF80: system.gpu.writeByte(address, value: value)
            
            case 0xFF0F: iFlag = InterruptByte(rawValue: value)
            case 0xFFFF: iEnable = InterruptByte(rawValue: value)
            case 0xFF80 ..< 0xFFFF: zram[address & 0x7F] = value
            default:
                print("Address not implemented (write): " + String(format: "%04X", address))
        }
    }
    
    func writeWord(_ address: UInt16, value: Word) {
        writeByte(address, value: Byte(truncatingIfNeeded: value))
        writeByte(address &+ 1, value: Byte(value >> 8)) //help
    }
    
    //TODO Pause CPU?
    //TODO Make faster
    ///Transfer dma from XX00-XX9F to FE00-FE9F
    func transferDMA(_ value: Byte) {
        let from = Word(value) << 8
        let to = Word(0xFE00)
        for i in Word(0) ..< 0xA0 {
            writeByte(to + i, value: readByte(from + i))
        }
    }
    
    func loadROM(data: [Byte]) {
        cartridge = Cartridge(data: data)
    }
    
    deinit {
        print("MMU released")
    }
}
