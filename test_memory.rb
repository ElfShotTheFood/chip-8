#!/usr/bin/env ruby
# Test script for the Memory module

require_relative 'memory'

puts "Testing Memory Module..."
puts

# Create a test object that includes the Memory module
memory_obj = Object.new
memory_obj.extend(Memory)

# Test 1: Initialize memory
puts "Test 1: Initialize memory"
memory_obj.initialize_memory
puts "  Memory size: #{memory_obj.memory.length} (expected 4096)"
puts "  All bytes zeroed: #{memory_obj.memory.all? { |b| b == 0 } }"
puts "  Fontset at 0x00: #{memory_obj.memory[0..4].inspect} (expected [240, 144, 144, 144, 240])"
puts

# Test 2: Read single byte
puts "Test 2: Read single byte"
value = memory_obj.read(0x200)
puts "  Read from 0x200: #{value} (expected 0)"
memory_obj.write(0x200, 0x42)
value = memory_obj.read(0x200)
puts "  After write, read from 0x200: #{value} (expected 0x42)"
puts

# Test 3: Write single byte
puts "Test 3: Write single byte"
memory_obj.write(0x300, 0xAB)
puts "  Value at 0x300: #{memory_obj.memory[0x300]} (expected 0xAB)"
# Verify value is masked to 8 bits
memory_obj.write(0x301, 0x1FF)
puts "  Value at 0x301 (0x1FF written): #{memory_obj.memory[0x301]} (expected 0xFF)"
puts

# Test 4: Read multiple bytes
puts "Test 4: Read multiple bytes"
test_data = [0x10, 0x20, 0x30, 0x40, 0x50]
memory_obj.write(0x400, test_data)
bytes = memory_obj.read(0x400, 5)
puts "  Written: #{test_data.inspect}"
puts "  Read:    #{bytes.inspect}"
puts "  Match:   #{bytes == test_data}"
puts

# Test 5: Write multiple bytes (array)
puts "Test 5: Write multiple bytes (array)"
more_data = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE]
memory_obj.write(0x500, more_data)
bytes = memory_obj.read(0x500, 5)
puts "  Written: #{more_data.inspect}"
puts "  Read:    #{bytes.inspect}"
puts "  Match:   #{bytes == more_data}"
puts

# Test 6: Load ROM
puts "Test 6: Load ROM"
rom = [0x00, 0xE0, 0x12, 0x34, 0x56, 0x78]
memory_obj.load_rom(rom)
rom_in_memory = memory_obj.read(0x200, rom.length)
puts "  ROM loaded at 0x200: #{rom_in_memory.inspect}"
puts "  Match: #{rom_in_memory == rom}"
puts "  Fontset still at 0x000: #{memory_obj.memory[0..4].inspect}"
puts

# Test 7: Boundary checks (no exceptions, just verify behavior)
puts "Test 7: Boundary checks"
# Reading beyond memory should return nil for out-of-bounds
result = memory_obj.read(4095, 10)  # Only 1 byte available at end
puts "  Read past end returns: #{result.inspect} (expected [last_byte])"
# Writing beyond memory should not crash
memory_obj.write(4090, [0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xA])
last_bytes = memory_obj.memory[4090..4095]
puts "  Written near end: #{last_bytes.inspect}"
puts

# Test 8: Word read (big-endian)
puts "Test 8: Word read (big-endian)"
memory_obj.write(0x600, [0x12, 0x34])
word = memory_obj.read_word(0x600)
puts "  Written: 0x12, 0x34 at 0x600"
puts "  Read word: 0x#{word.to_s(16).upcase} (expected 0x1234)"
puts

puts "All memory tests completed!"