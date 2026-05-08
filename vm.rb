# CHIP-8 Virtual Machine
# Main VM implementation with instruction execution and stubbed I/O

require_relative 'memory'
require_relative 'display'

class VM
  include Memory
  include Display

  # CHIP-8 has 16 8-bit registers (V0-VF)
  # VF is used as a flag register for carry/borrow/collision
  attr_accessor :v, :i, :pc, :sp, :stack, :delay_timer, :sound_timer

  def initialize(scaling_factor = 10)
    reset(scaling_factor)
  end

  # Reset the virtual machine to its initial state
  def reset(scaling_factor = 10)
    initialize_memory
    initialize_display(scaling_factor)
    @v = Array.new(16, 0)        # 16 general purpose registers
    @i = 0                       # Index register (12-bit)
    @pc = 0x200                  # Program counter starts at 0x200
    @sp = 0                      # Stack pointer
    @stack = Array.new(16, 0)    # Stack for subroutine calls (16 levels)
    @delay_timer = 0             # Delay timer (60Hz)
    @sound_timer = 0             # Sound timer (60Hz, beeps while > 0)

    # Stubbed I/O components (to be implemented with GTK3/Gosu later)
    @keypad = nil    # Keypad state (16 keys: 0x0-0xF)

    # Initialize random number generator seed
    srand
  end

  # Execute a single CHIP-8 instruction
  # instruction: 16-bit opcode
  def execute_instruction(instruction)
    # Extract the instruction components
    opcode = instruction >> 12
    x = (instruction >> 8) & 0xF
    y = (instruction >> 4) & 0xF
    n = instruction & 0xF
    kk = instruction & 0xFF
    nnn = instruction & 0xFFF

    case opcode
    when 0x0
      # 00E0 - Clear screen
      if instruction == 0x00E0
        clear_display
      # 00EE - Return from subroutine
      elsif instruction == 0x00EE
        return_from_subroutine
      else
        # 0NNN - Call RCA 1802 program (ignored on modern interpreters)
        # No operation for now
      end
    when 0x1
      # 1NNN - Jump to address NNN
      jump_to(nnn)
    when 0x2
      # 2NNN - Call subroutine at NNN
      call_subroutine(nnn)
    when 0x3
      # 3XKK - Skip next instruction if Vx == KK
      skip_if_equal(x, kk)
    when 0x4
      # 4XKK - Skip next instruction if Vx != KK
      skip_if_not_equal(x, kk)
    when 0x5
      # 5XY0 - Skip next instruction if Vx == Vy
      skip_if_registers_equal(x, y)
    when 0x6
      # 6XKK - Set Vx = KK
      set_register_immediate(x, kk)
    when 0x7
      # 7XKK - Add KK to Vx (no carry)
      add_to_register(x, kk)
    when 0x8
      case n
      when 0x0
        # 8XY0 - Set Vx = Vy
        set_register_from_register(x, y)
      when 0x1
        # 8XY1 - Vx = Vx OR Vy
        or_registers(x, y)
      when 0x2
        # 8XY2 - Vx = Vx AND Vy
        and_registers(x, y)
      when 0x3
        # 8XY3 - Vx = Vx XOR Vy
        xor_registers(x, y)
      when 0x4
        # 8XY4 - Vx += Vy, set VF on carry
        add_registers(x, y)
      when 0x5
        # 8XY5 - Vx -= Vy, set VF on no borrow
        subtract_registers(x, y)
      when 0x6
        # 8XY6 - Vx >>= 1, store LSB in VF
        shift_right(x, y)
      when 0x7
        # 8XY7 - Vx = Vy - Vx, set VF on no borrow
        reverse_subtract(x, y)
      when 0xE
        # 8XYE - Vx <<= 1, store MSB in VF
        shift_left(x, y)
      else
        # Unknown instruction
        unknown_instruction(instruction)
      end
    when 0x9
      # 9XY0 - Skip next instruction if Vx != Vy
      skip_if_registers_not_equal(x, y)
    when 0xA
      # ANNN - Set I = NNN
      set_index_register(nnn)
    when 0xB
      # BNNN - Jump to NNN + V0
      jump_to_offset(nnn)
    when 0xC
      # CXKK - Vx = random_byte & KK
      random_and(x, kk)
    when 0xD
      # DXYN - Draw sprite at (Vx, Vy) with N rows of 8 bits
      draw_sprite(x, y, n)
    when 0xE
      if kk == 0x9E
        # EX9E - Skip next instruction if key Vx is pressed
        skip_if_key_pressed(x)
      elsif kk == 0xA1
        # EXA1 - Skip next instruction if key Vx is not pressed
        skip_if_key_not_pressed(x)
      else
        unknown_instruction(instruction)
      end
    when 0xF
      case kk
      when 0x07
        # FX07 - Set Vx = delay_timer
        set_register_from_delay_timer(x)
      when 0x0A
        # FX0A - Wait for key press, store in Vx
        wait_for_key(x)
      when 0x15
        # FX15 - Set delay_timer = Vx
        set_delay_timer(x)
      when 0x18
        # FX18 - Set sound_timer = Vx
        set_sound_timer(x)
      when 0x1E
        # FX1E - I += Vx
        add_to_index(x)
      when 0x29
        # FX29 - Set I to font sprite for digit Vx
        set_index_to_font(x)
      when 0x33
        # FX33 - Store BCD representation of Vx in memory at I
        store_bcd(x)
      when 0x55
        # FX55 - Store registers V0-Vx in memory starting at I
        store_registers(x)
      when 0x65
        # FX65 - Read registers V0-Vx from memory starting at I
        load_registers(x)
      else
        unknown_instruction(instruction)
      end
    else
      unknown_instruction(instruction)
    end

    # Increment program counter (most instructions advance PC by 2)
    # Note: Instructions that modify PC (jumps, calls, skips) handle this themselves
  end

  # ==================== Instruction Implementations ====================

  def clear_display
    # Implemented via Display module
    clear
  end

  def return_from_subroutine
    @sp -= 1
    @pc = @stack[@sp]
  end

  def jump_to(address)
    @pc = address
  end

  def call_subroutine(address)
    @stack[@sp] = @pc
    @sp += 1
    @pc = address
  end

  def skip_if_equal(reg, value)
    @pc += 2 if @v[reg] == value
  end

  def skip_if_not_equal(reg, value)
    @pc += 2 if @v[reg] != value
  end

  def skip_if_registers_equal(x, y)
    @pc += 2 if @v[x] == @v[y]
  end

  def set_register_immediate(reg, value)
    @v[reg] = value
  end

  def add_to_register(reg, value)
    @v[reg] = (@v[reg] + value) & 0xFF
  end

  def set_register_from_register(x, y)
    @v[x] = @v[y]
  end

  def or_registers(x, y)
    @v[x] = @v[x] | @v[y]
  end

  def and_registers(x, y)
    @v[x] = @v[x] & @v[y]
  end

  def xor_registers(x, y)
    @v[x] = @v[x] ^ @v[y]
  end

  def add_registers(x, y)
    sum = @v[x] + @v[y]
    @v[0xF] = (sum > 0xFF) ? 1 : 0
    @v[x] = sum & 0xFF
  end

  def subtract_registers(x, y)
    @v[0xF] = (@v[x] >= @v[y]) ? 1 : 0
    @v[x] = (@v[x] - @v[y]) & 0xFF
  end

  def shift_right(x, y)
    # In original CHIP-8, Vx is shifted right by 1, LSB stored in VF
    # Some implementations use Vy's value, others ignore it
    @v[0xF] = @v[x] & 0x1
    @v[x] = @v[x] >> 1
  end

  def reverse_subtract(x, y)
    @v[0xF] = (@v[y] >= @v[x]) ? 1 : 0
    @v[x] = (@v[y] - @v[x]) & 0xFF
  end

  def shift_left(x, y)
    # In original CHIP-8, Vx is shifted left by 1, MSB stored in VF
    @v[0xF] = (@v[x] >> 7) & 0x1
    @v[x] = (@v[x] << 1) & 0xFF
  end

  def skip_if_registers_not_equal(x, y)
    @pc += 2 if @v[x] != @v[y]
  end

  def set_index_register(address)
    @i = address
  end

  def jump_to_offset(address)
    @pc = address + @v[0]
  end

  def random_and(x, mask)
    random_byte = rand(0..255)
    @v[x] = random_byte & mask
  end

  def draw_sprite(x_reg, y_reg, height)
    # Draw a sprite at coordinates (Vx, Vy)
    # Each row of the sprite is 8 bits wide, stored in memory at I
    # Pixels are XOR'd onto the display buffer
    # VF is set to 1 if any pixels are turned off (collision), 0 otherwise

    x = @v[x_reg]
    y = @v[y_reg]
    @v[0xF] = 0  # No collision initially

    height.times do |row|
      # Get the sprite byte from memory
      sprite_byte = @memory[@i + row]

      # Process each bit in the byte (left to right)
      8.times do |col|
        pixel_bit = (sprite_byte >> (7 - col)) & 0x1

        if pixel_bit == 1
          # XOR the pixel at (x + col, y + row)
          collision = xor_pixel(x + col, y + row)
          @v[0xF] = 1 if collision == 1  # Pixel was on, so collision occurred
        end
      end
    end
  end

  def skip_if_key_pressed(reg)
    # Stub: Skip if key Vx is pressed
    # key = @v[reg]
    # @pc += 2 if @keypad[key] == 1
  end

  def skip_if_key_not_pressed(reg)
    # Stub: Skip if key Vx is not pressed
    # key = @v[reg]
    # @pc += 2 if @keypad[key] == 0
  end

  def set_register_from_delay_timer(reg)
    @v[reg] = @delay_timer
  end

  def wait_for_key(reg)
    # Stub: Wait for a key press, store key value in Vx
    # Block until a key is pressed, then store the key value in Vx
    # This is a blocking operation
  end

  def set_delay_timer(reg)
    @delay_timer = @v[reg]
  end

  def set_sound_timer(reg)
    @sound_timer = @v[reg]
  end

  def add_to_index(reg)
    @i = (@i + @v[reg]) & 0xFFF
  end

  def set_index_to_font(reg)
    # Each font character is 5 bytes, so multiply by 5
    @i = @v[reg] * 5
  end

  def store_bcd(reg)
    # Store BCD representation of Vx in memory at I
    # Hundreds digit at I, tens at I+1, ones at I+2
    value = @v[reg]
    @memory[@i] = value / 100
    @memory[@i + 1] = (value % 100) / 10
    @memory[@i + 2] = value % 10
  end

  def store_registers(reg)
    # Store registers V0-Vx in memory starting at I
    (0..reg).each do |i|
      @memory[@i + i] = @v[i]
    end
  end

  def load_registers(reg)
    # Load registers V0-Vx from memory starting at I
    (0..reg).each do |i|
      @v[i] = @memory[@i + i]
    end
  end

  def unknown_instruction(instruction)
    # Stub: Handle unknown/unimplemented instructions
    # Could log a warning or raise an error in debug mode
    # puts "Unknown instruction: 0x#{instruction.to_s(16).upcase}"
  end

  # ==================== Stubbed I/O Methods ====================

  def set_keypad(keypad_obj)
    @keypad = keypad_obj
  end

  def update_timers
    # Decrement delay and sound timers at 60Hz
    @delay_timer -= 1 if @delay_timer > 0
    @sound_timer -= 1 if @sound_timer > 0
  end

  def beep?
    # Return true if sound timer is non-zero (should be playing sound)
    @sound_timer > 0
  end
end