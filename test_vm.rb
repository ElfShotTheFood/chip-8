#!/usr/bin/env ruby
# Simple test script to verify the CHIP-8 VM implementation

require_relative 'vm'

# Create a new VM instance
puts "Creating VM instance..."
vm = VM.new

# Test reset
puts "Testing reset()..."
vm.reset
puts "  Registers: #{vm.v.inspect}"
puts "  PC: 0x#{vm.pc.to_s(16).upcase}"
puts "  I: 0x#{vm.i.to_s(16).upcase}"
puts "  SP: #{vm.sp}"
puts "  Stack: #{vm.stack.inspect}"
puts "  Memory size: #{vm.memory.length}"
puts "  Fontset loaded: #{vm.memory[0..4].inspect}"

# Test loading a ROM
puts "\nTesting ROM loading..."
test_rom = [0x00, 0xE0, 0x12, 0x34]  # Clear screen, call 0x234
vm.load_rom(test_rom)
puts "  ROM loaded at 0x200: #{vm.memory[0x200..0x203].inspect}"

# Test execute_instruction with a simple instruction
puts "\nTesting execute_instruction()..."
vm.reset
vm.v[0] = 0x10
vm.v[1] = 0x20
instruction = 0x8010  # 8XY0 - Set V0 = V1
vm.execute_instruction(instruction)
puts "  After 8XY0 (V0 = V1): V0 = 0x#{vm.v[0].to_s(16).upcase} (expected 0x20)"

# Test 6XKK - Set Vx = KK
vm.reset
instruction = 0x6123  # Set V1 = 0x23
vm.execute_instruction(instruction)
puts "  After 6XKK (V1 = 0x23): V1 = 0x#{vm.v[1].to_s(16).upcase} (expected 0x23)"

# Test 7XKK - Add KK to Vx
vm.reset
vm.v[2] = 0x10
instruction = 0x7205  # Add 0x05 to V2
vm.execute_instruction(instruction)
puts "  After 7XKK (V2 += 0x05): V2 = 0x#{vm.v[2].to_s(16).upcase} (expected 0x15)"

# Test ANNN - Set I
vm.reset
instruction = 0xA123  # Set I = 0x123
vm.execute_instruction(instruction)
puts "  After ANNN (I = 0x123): I = 0x#{vm.i.to_s(16).upcase} (expected 0x123)"

# Test 1NNN - Jump
vm.reset
instruction = 0x1234  # Jump to 0x234
vm.execute_instruction(instruction)
puts "  After 1NNN (PC = 0x234): PC = 0x#{vm.pc.to_s(16).upcase} (expected 0x234)"

# Test 2NNN - Call subroutine
vm.reset
vm.pc = 0x200
instruction = 0x2345  # Call 0x345
vm.execute_instruction(instruction)
puts "  After 2NNN (call subroutine):"
puts "    PC = 0x#{vm.pc.to_s(16).upcase} (expected 0x345)"
puts "    Stack[0] = 0x#{vm.stack[0].to_s(16).upcase} (expected 0x200)"
puts "    SP = #{vm.sp} (expected 1)"

# Test 00EE - Return from subroutine
vm.return_from_subroutine
puts "  After 00EE (return): PC = 0x#{vm.pc.to_s(16).upcase} (expected 0x200)"

# Test BCD conversion
puts "\nTesting BCD conversion (FX33)..."
vm.reset
vm.v[0] = 123
vm.i = 0x300
vm.store_bcd(0)
puts "  BCD of 123: memory[0x300]=#{vm.memory[0x300]}, memory[0x301]=#{vm.memory[0x301]}, memory[0x302]=#{vm.memory[0x302]}"
puts "  Expected: 1, 2, 3"

# Test register load/store
puts "\nTesting register load/store..."
vm.reset
(0..5).each { |i| vm.v[i] = i * 10 }
vm.i = 0x400
vm.store_registers(5)
puts "  Stored V0-V5 to memory: #{vm.memory[0x400..0x406].inspect}"
vm.load_registers(5)
puts "  Loaded V0-V5 from memory: #{vm.v[0..5].inspect}"

puts "\nAll basic tests completed!"