# CHIP-8 Display Module
# Handles the 64x32 pixel display buffer with scaling support

module Display
  # CHIP-8 display dimensions
  WIDTH = 64
  HEIGHT = 32

  attr_accessor :buffer, :scaling_factor

  def initialize_display(scaling_factor = 10)
    @scaling_factor = scaling_factor
    clear
  end

  # Clear the display buffer (all pixels off)
  def clear
    @buffer = Array.new(HEIGHT) { Array.new(WIDTH, 0) }
  end

  # Set a pixel at (x, y) to ON (1)
  def set_pixel(x, y)
    # Wrap coordinates if needed (CHIP-8 display wraps around)
    x = x % WIDTH
    y = y % HEIGHT
    @buffer[y][x] = 1
  end

  # Clear a pixel at (x, y) to OFF (0)
  def clear_pixel(x, y)
    x = x % WIDTH
    y = y % HEIGHT
    @buffer[y][x] = 0
  end

  # XOR a pixel at (x, y) - toggle state, return new value
  # Returns 1 if pixel was turned off (collision), 0 otherwise
  def xor_pixel(x, y)
    x = x % WIDTH
    y = y % HEIGHT
    old_value = @buffer[y][x]
    @buffer[y][x] = (old_value == 0) ? 1 : 0
    return old_value  # Return the original value (1 if pixel was on, 0 if off)
  end

  # Get the pixel state at (x, y)
  def get_pixel(x, y)
    x = x % WIDTH
    y = y % HEIGHT
    @buffer[y][x]
  end

  # Calculate the native window dimensions based on scaling factor
  def window_width
    WIDTH * @scaling_factor
  end

  def window_height
    HEIGHT * @scaling_factor
  end

  # Convert CHIP-8 coordinates to native window coordinates
  def to_window_coords(x, y)
    [x * @scaling_factor, y * @scaling_factor]
  end

  # Get the display buffer (for rendering)
  def get_buffer
    @buffer
  end

  # Set the scaling factor and recalculate window dimensions
  def set_scaling_factor(factor)
    @scaling_factor = factor
  end
end