#!/usr/bin/env ruby
# CHIP-8 GUI Application
# Main application window with control buttons and VM state displays

require_relative 'vm'
require_relative 'display'
require 'gtk3'

class Chip8App
  def initialize
    # Create the virtual machine with default scaling
    @vm = VM.new(10)

    # Build the GUI
    build_ui

    # Set up timer for emulation loop
    @running = false
    @single_step_mode = false
  end

  def build_ui
    # Create main window
    @window = Gtk::Window.new('CHIP-8 Emulator')
    @window.set_default_size(800, 600)
    @window.signal_connect('destroy') { |_| Gtk.main_quit }

    # Main vertical box
    main_vbox = Gtk::Box.new(:vertical, 5)
    @window.add(main_vbox)

    # ==================== CONTROL GROUP ====================
    control_frame = Gtk::Frame.new('Control')
    control_box = Gtk::Box.new(:horizontal, 5)
    control_frame.add(control_box)

    @run_button = Gtk::Button.new(label: 'RUN')
    @stop_button = Gtk::Button.new(label: 'STOP')
    @step_button = Gtk::Button.new(label: 'SINGLE STEP')
    @reset_button = Gtk::Button.new(label: 'RESET')

    # Connect button signals
    @run_button.signal_connect('clicked') { |_| on_run_clicked }
    @stop_button.signal_connect('clicked') { |_| on_stop_clicked }
    @step_button.signal_connect('clicked') { |_| on_step_clicked }
    @reset_button.signal_connect('clicked') { |_| on_reset_clicked }

    control_box.pack_start(@run_button, expand: true, fill: true, padding: 5)
    control_box.pack_start(@stop_button, expand: true, fill: true, padding: 5)
    control_box.pack_start(@step_button, expand: true, fill: true, padding: 5)
    control_box.pack_start(@reset_button, expand: true, fill: true, padding: 5)

    main_vbox.pack_start(control_frame, expand: false, fill: false, padding: 5)

    # ==================== DISPLAY AREA ====================
    # Create a drawing area for the CHIP-8 display
    display_frame = Gtk::Frame.new('Display')
    @drawing_area = Gtk::DrawingArea.new
    @drawing_area.set_size_request(@vm.window_width, @vm.window_height)
    # Connect draw signal
    @drawing_area.signal_connect('draw') { |area, cr| on_draw_display(area, cr) }
    display_frame.add(@drawing_area)
    main_vbox.pack_start(display_frame, expand: false, fill: false, padding: 5)

    # ==================== INFO GROUPS (SIDE BY SIDE) ====================
    info_hbox = Gtk::Box.new(:horizontal, 5)
    main_vbox.pack_start(info_hbox, expand: true, fill: true, padding: 5)

    # Get the background color from the window for matching
    bg_color = @window.style_context.get_background_color(Gtk::StateFlags::NORMAL)

    # ----- Registers Group -----
    registers_frame = Gtk::Frame.new('Registers')
    @registers_view = Gtk::TextView.new
    @registers_view.editable = false
    @registers_view.cursor_visible = false
    style_textview(@registers_view, bg_color)
    registers_frame.add(@registers_view)
    info_hbox.pack_start(registers_frame, expand: true, fill: true, padding: 5)

    # ----- Stack Group -----
    stack_frame = Gtk::Frame.new('Stack')
    @stack_view = Gtk::TextView.new
    @stack_view.editable = false
    @stack_view.cursor_visible = false
    style_textview(@stack_view, bg_color)
    stack_frame.add(@stack_view)
    info_hbox.pack_start(stack_frame, expand: true, fill: true, padding: 5)

    # ----- Memory Group -----
    memory_frame = Gtk::Frame.new('Memory')
    @memory_view = Gtk::TextView.new
    @memory_view.editable = false
    @memory_view.cursor_visible = false
    style_textview(@memory_view, bg_color)
    memory_frame.add(@memory_view)
    info_hbox.pack_start(memory_frame, expand: true, fill: true, padding: 5)

    # ----- Trace Group -----
    trace_frame = Gtk::Frame.new('Trace')
    @trace_view = Gtk::TextView.new
    @trace_view.editable = false
    @trace_view.cursor_visible = false
    style_textview(@trace_view, bg_color)
    trace_frame.add(@trace_view)
    info_hbox.pack_start(trace_frame, expand: true, fill: true, padding: 5)

    # Status bar at bottom
    @status_bar = Gtk::Label.new('Ready')
    main_vbox.pack_start(@status_bar, expand: false, fill: false, padding: 5)

    # Show all widgets
    @window.show_all

    # Initial update
    update_display
    update_info_panels
  end

  # Helper to set Consolas monospace font and match background on a textview
  def style_textview(textview, bg_color)
    font_desc = Pango::FontDescription.new('Consolas 10')
    textview.override_font(font_desc)
    # Set background to match main window using override_background_color
    textview.override_background_color(Gtk::StateFlags::NORMAL, bg_color)
  end

  # ==================== BUTTON HANDLERS ====================

  def on_run_clicked
    if !@running
      @running = true
      @single_step_mode = false
      @status_bar.text = 'Running...'
      # Start the emulation loop using GTK's idle_add
      GLib::Idle.add { emulation_loop }
    end
  end

  def on_stop_clicked
    @running = false
    @single_step_mode = false
    @status_bar.text = 'Stopped'
  end

  def on_step_clicked
    if !@running
      @single_step_mode = true
      @status_bar.text = 'Single step mode'
      execute_single_step
    end
  end

  def on_reset_clicked
    @running = false
    @single_step_mode = false
    @vm.reset
    @status_bar.text = 'Reset complete'
    update_display
    update_info_panels
  end

  # ==================== EMULATION LOOP ====================

  def emulation_loop
    return false unless @running

    # Execute one instruction
    instruction = @vm.read_word(@vm.pc)
    @vm.execute_instruction(instruction)
    @vm.pc += 2

    # Update timers at 60Hz (simplified - in real implementation would use proper timing)
    @vm.update_timers

    # Update GUI
    update_display
    update_info_panels

    # Continue the loop
    true
  end

  def execute_single_step
    instruction = @vm.read_word(@vm.pc)
    @vm.execute_instruction(instruction)
    @vm.pc += 2
    @vm.update_timers
    update_display
    update_info_panels
  end

  # ==================== GUI UPDATE METHODS ====================

  def update_display
    # Redraw the CHIP-8 display on the drawing area
    @drawing_area.queue_draw
  end

  def update_info_panels
    update_registers_panel
    update_stack_panel
    update_memory_panel
    update_trace_panel
  end

  def update_registers_panel
    buffer = @registers_view.buffer
    text = "V0-VF Registers:\n\n"
    16.times do |i|
      text += sprintf("V%X: 0x%02X  ", i, @vm.v[i])
      text += "\n" if (i % 4 == 3)
    end
    text += "\nI:  0x#{@vm.i.to_s(16).upcase}\n"
    text += "PC: 0x#{@vm.pc.to_s(16).upcase}\n"
    text += "SP: #{@vm.sp}\n"
    text += "Delay: #{@vm.delay_timer}\n"
    text += "Sound: #{@vm.sound_timer}"
    buffer.text = text
  end

  def update_stack_panel
    buffer = @stack_view.buffer
    text = "Stack (#{@vm.sp} entries):\n\n"
    @vm.stack[0...@vm.sp].each_with_index do |value, index|
      text += sprintf("[%02d] 0x%04X\n", index, value)
    end
    buffer.text = text
  end

  def update_memory_panel
    buffer = @memory_view.buffer
    text = "Memory (0x200-0x20F):\n\n"
    # Show first 16 bytes of ROM area
    (0x200..0x20F).each do |addr|
      value = @vm.read(addr)
      text += sprintf("0x%03X: 0x%02X\n", addr, value)
    end
    buffer.text = text
  end

  def update_trace_panel
    buffer = @trace_view.buffer
    text = "Instruction Trace:\n\n"
    # Show last few executed instructions (simplified)
    # In a full implementation, this would log executed opcodes
    text += "PC: 0x#{@vm.pc.to_s(16).upcase}\n"
    if @vm.pc < 0xFFF
      next_instr = @vm.read_word(@vm.pc)
      text += "Next: 0x#{next_instr.to_s(16).upcase}\n"
    end
    buffer.text = text
  end

  # ==================== DRAWING ====================

  def on_draw_display(area, cr)
    # Get the display buffer from the VM
    buffer = @vm.get_buffer

    # Draw each pixel as a rectangle
    @vm.scaling_factor.times do |y|
      @vm.scaling_factor.times do |x|
        # Calculate the CHIP-8 pixel coordinates
        chip_x = x
        chip_y = y

        # Get pixel state
        pixel = buffer[chip_y][chip_x]

        # Set color (white for on, black for off)
        if pixel == 1
          cr.set_source_rgb(1, 1, 1)  # White
        else
          cr.set_source_rgb(0, 0, 0)  # Black
        end

        # Draw the scaled pixel rectangle
        cr.rectangle(
          x * @vm.scaling_factor,
          y * @vm.scaling_factor,
          @vm.scaling_factor,
          @vm.scaling_factor
        )
        cr.fill
      end
    end

    # Return false to stop event propagation
    false
  end

  # ==================== MAIN ENTRY POINT ====================

  def self.run
    app = Chip8App.new
    Gtk.main
  end
end

# Start the application if this file is executed directly
if __FILE__ == $0
  Chip8App.run
end