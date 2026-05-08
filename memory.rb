# CHIP-8 Memory Module
# Handles the 4KB (4096 bytes) of memory for the virtual machine

module Memory
  MEMORY_SIZE = 4096
  ROM_START = 0x200  # CHIP-8 programs start at 0x200

  attr_accessor :memory

  def initialize_memory
    @memory = Array.new(MEMORY_SIZE, 0)
    # Load fontset into memory (starting at 0x000)
    load_fontset
  end

  def load_fontset
    # CHIP-8 fontset: each digit 0-F represented as a 5-byte sprite
    fontset = [
      0xF0, 0x90, 0x90, 0x90, 0xF0, # 0
      0x20, 0x60, 0x20, 0x20, 0x70, # 1
      0xF0, 0x10, 0xF0, 0x80, 0xF0, # 2
      0xF0, 0x10, 0xF0, 0x10, 0xF0, # 3
      0x90, 0x90, 0xF0, 0x10, 0x10, # 4
      0xF0, 0x80, 0xF0, 0x10, 0xF0, # 5
      0xF0, 0x80, 0xF0, 0x90, 0xF0, # 6
      0xF0, 0x10, 0x20, 0x40, 0x40, # 7
      0xF0, 0x90, 0xF0, 0x90, 0xF0, # 8
      0xF0, 0x90, 0xF0, 0x10, 0xF0, # 9
      0xF0, 0x90, 0xF0, 0x90, 0x90, # A
      0xE0, 0x90, 0xE0, 0x90, 0xE0, # B
      0xF0, 0x80, 0x80, 0x80, 0xF0, # C
      0xE0, 0x90, 0x90, 0x90, 0xE0, # D
      0xF0, 0x80, 0xF0, 0x80, 0xF0, # E
      0xF0, 0x80, 0xF0, 0x80, 0x80  # F
    ]

    fontset.each_with_index do |byte, index|
      @memory[index] = byte
    end
  end

  def load_rom(rom_data)
    # Load ROM data starting at ROM_START address
    rom_data.each_with_index do |byte, index|
      @memory[ROM_START + index] = byte
    end
  end

  # Read a single byte from the specified address
  # OR read multiple bytes if size argument is provided
  def read(address, size = nil)
    if size.nil?
      # Single byte read
      @memory[address]
    else
      # Multiple byte read - returns array of bytes
      @memory[address, size]
    end
  end

  # Write a single byte or multiple bytes to the specified address
  def write(address, value)
    if value.is_a?(Array)
      # Write multiple bytes
      value.each_with_index do |val, index|
        @memory[address + index] = val & 0xFF
      end
    else
      # Write single byte
      @memory[address] = value & 0xFF
    end
  end

  # Read a 16-bit word (2 bytes) from the specified address in big-endian format
  def read_word(address)
    (@memory[address] << 8) | @memory[address + 1]
  end
end