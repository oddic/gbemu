//
//  Gameboy.swift
//  gbemu
//
//  Created by Otis Carpay on 11/09/15.
//  Copyright © 2015 Otis Carpay. All rights reserved.
//

import Cocoa

typealias Byte = UInt8
typealias Word = UInt16
extension UnsignedInteger {
    init(_ bool: Bool) {
        self.init(bool ? 1 : 0)
    }
    
    func hasBit(_ bit: Int) -> Bool {
        return self & 1 << bit != 0
    }
    
    func setBit<T: BinaryInteger>(_ bit: Int, value: T) -> Self {
        if value == 0 {
            return self & ~(1 << bit)
        } else {
            return self | 1 << bit
        }
    }
}

var ramSaveCounter = 0

extension Byte {
    func inBools() -> (Bool, Bool, Bool, Bool, Bool, Bool, Bool, Bool) {
        return (
            self & 0x01 != 0, self & 0x02 != 0, self & 0x04 != 0, self & 0x08 != 0,
            self & 0x10 != 0, self & 0x20 != 0, self & 0x40 != 0, self & 0x80 != 0
        )
    }
}

final class Gameboy {
    var joypad: Joypad!
    let screen: GPUOutputReceiver
    
    private(set) public var stopped = false
    private var inactive = true //Whether there is no thread running
    
    var cpu: CPU!
    var gpu: GPU!
    var apu = APU()
    
    private let frameTicks = 17556
    
    init(screen: GPUOutputReceiver) {
        self.screen = screen
        gpu = GPU(system: self, screen: screen)
        cpu = CPU(system: self) // Can be better?
        joypad = Joypad(system: self)
    }
    
    func reset(withRom rom: [Byte]) {
        while (!inactive) { usleep(1000) } //can this be better?
        
        print("\nReset-----------")
        gpu = GPU(system: self, screen: screen)
        cpu = CPU(system: self)
        apu = APU()
        
        cpu.mmu.loadROM(data: rom)
    }
    
    var count = 0
    
    func runFrame() {
        if !stopped {
            inactive = false
            
            while count < frameTicks {
                let m = cpu.step()
                gpu.step(m)
                apu.step(m)
                count += m
            }
            
            count -= frameTicks
            ramSaveCounter += 1
            if ramSaveCounter > 60 && cpu.mmu.cartridge.ramIsDirty {
                cpu.mmu.cartridge.saveRAM()
                cpu.mmu.cartridge.ramIsDirty = false
                ramSaveCounter = 0
            }
        } else {
            inactive = true
        }
    }
}
