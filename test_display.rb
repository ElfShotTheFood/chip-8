#!/usr/bin/env ruby
# Test script for the Display module

require_relative 'display'

puts "Testing Display Module..."
puts

# Test 1: Initialize with default scaling factor
puts "Test 1: Initialize with default scaling factor (10)"
display = Object.new
display.extend(Display)
display.initialize_display
puts "  Buffer size: #{display.buffer.length} rows x #{display.buffer[0].length} columns"
puts "  Scaling factor: #{display.scaling_factor}"
puts "  Window dimensions: #{display.window_width}x#{display.window_height}"
puts "  Expected: 640x320"
puts

# Test 2: Initialize with custom scaling factor
puts "Test 2: Initialize with custom scaling factor (5)"
display2 = Object.new
display2.extend(Display)
display2.initialize_display(5)
puts "  Scaling factor: #{display2.scaling_factor}"
puts "  Window dimensions: #{display2.window_width}x#{display2.window_height}"
puts "  Expected: 320x160"
puts

# Test 3: Clear display
puts "Test 3: Clear display"
display.clear
all_zeros = display.buffer.flatten.all? { |p| p == 0 }
puts "  All pixels cleared: #{all_zeros}"
puts

# Test 4: Set pixel
puts "Test 4: Set pixel"
display.set_pixel(10, 5)
puts "  Pixel at (10,5): #{display.get_pixel(10, 5)} (expected 1)"
puts "  Pixel at (0,0): #{display.get_pixel(0, 0)} (expected 0)"
puts

# Test 5: Clear pixel
puts "Test 5: Clear pixel"
display.clear_pixel(10, 5)
puts "  Pixel at (10,5) after clear: #{display.get_pixel(10, 5)} (expected 0)"
puts

# Test 6: XOR pixel (toggle)
puts "Test 6: XOR pixel (toggle)"
display.set_pixel(20, 10)
puts "  Pixel at (20,10) initially: #{display.get_pixel(20, 10)} (expected 1)"
collision = display.xor_pixel(20, 10)
puts "  XOR returned: #{collision} (expected 1 - pixel was on)"
puts "  Pixel at (20,10) after XOR: #{display.get_pixel(20, 10)} (expected 0)"
collision2 = display.xor_pixel(20, 10)
puts "  XOR returned: #{collision2} (expected 0 - pixel was off)"
puts "  Pixel at (20,10) after second XOR: #{display.get_pixel(20, 10)} (expected 1)"
puts

# Test 7: Coordinate wrapping
puts "Test 7: Coordinate wrapping"
display.clear
display.set_pixel(65, 5)   # x=65 should wrap to 65 % 64 = 1
display.set_pixel(10, 33)  # y=33 should wrap to 33 % 32 = 1
puts "  Pixel at (65,5) stored at: should be (1,5) - check buffer[5][1] = #{display.buffer[5][1]}"
puts "  Pixel at (10,33) stored at: should be (10,1) - check buffer[1][10] = #{display.buffer[1][10]}"
puts

# Test 8: Set scaling factor
puts "Test 8: Set scaling factor"
display.set_scaling_factor(20)
puts "  New scaling factor: #{display.scaling_factor}"
puts "  New window dimensions: #{display.window_width}x#{display.window_height}"
puts "  Expected: 1280x640"
puts

# Test 9: Convert coordinates
puts "Test 9: Convert CHIP-8 to window coordinates"
coords = display.to_window_coords(5, 3)
puts "  CHIP-8 (5,3) with scaling 20 -> window (#{coords[0]}, #{coords[1]})"
puts "  Expected: (100, 60)"
puts

puts "All display tests completed!"