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
    control_frame = create_bold_frame('Control')
    control_box = Gtk::Box.new(:horizontal, 5)
    control_frame.add(control_box)

    @run_button = Gtk::Button.new(label: 'RUN')
    @stop_button = Gtk::Button.new(label: 'STOP')
    @step_button = Gtk::Button.new(label: 'SINGLE STEP')
    @reset_button = Gtk::Button.new(label: 'RESET')
    @load_rom_button = Gtk::Button.new(label: 'LOAD ROM')
    @save_rom_button = Gtk::Button.new(label: 'SAVE ROM')

    # Connect button signals
    @run_button.signal_connect('clicked') { |_| on_run_clicked }
    @stop_button.signal_connect('clicked') { |_| on_stop_clicked }
    @step_button.signal_connect('clicked') { |_| on_step_clicked }
    @reset_button.signal_connect('clicked') { |_| on_reset_clicked }
    @load_rom_button.signal_connect('clicked') { |_| on_load_rom_clicked }
    @save_rom_button.signal_connect('clicked') { |_| on_save_rom_clicked }

    control_box.pack_start(@run_button, expand: true, fill: true, padding: 5)
    control_box.pack_start(@stop_button, expand: true, fill: true, padding: 5)
    control_box.pack_start(@step_button, expand: true, fill: true, padding: 5)
    control_box.pack_start(@reset_button, expand: true, fill: true, padding: 5)
    control_box.pack_start(@load_rom_button, expand: true, fill: true, padding: 5)
    control_box.pack_start(@save_rom_button, expand: true, fill: true, padding: 5)

    main_vbox.pack_start(control_frame, expand: false, fill: false, padding: 5)

    # ==================== INFO GROUPS (SIDE BY SIDE) ====================
    info_hbox = Gtk::Box.new(:horizontal, 5)
    main_vbox.pack_start(info_hbox, expand: true, fill: true, padding: 5)

    # Get the background color from the window for matching
    bg_color = @window.style_context.get_background_color(Gtk::StateFlags::NORMAL)

    # ----- Registers Group -----
    registers_frame = create_bold_frame('Registers')
    @registers_view = Gtk::TextView.new
    @registers_view.editable = false
    @registers_view.cursor_visible = false
    style_textview(@registers_view, bg_color)
    registers_frame.add(@registers_view)
    info_hbox.pack_start(registers_frame, expand: true, fill: true, padding: 5)

    # ----- Stack Group -----
    stack_frame = create_bold_frame('Stack')
    @stack_view = Gtk::TextView.new
    @stack_view.editable = false
    @stack_view.cursor_visible = false
    style_textview(@stack_view, bg_color)
    stack_frame.add(@stack_view)
    info_hbox.pack_start(stack_frame, expand: true, fill: true, padding: 5)

    # ----- Memory Group -----
    memory_frame = create_bold_frame('Memory')
    @memory_view = Gtk::TextView.new
    @memory_view.editable = false
    @memory_view.cursor_visible = false
    style_textview(@memory_view, bg_color)
    memory_frame.add(@memory_view)
    info_hbox.pack_start(memory_frame, expand: true, fill: true, padding: 5)

    # ----- Trace Group -----
    trace_frame = create_bold_frame('Trace')
    @trace_view = Gtk::TextView.new
    @trace_view.editable = false
    @trace_view.cursor_visible = false
    style_textview(@trace_view, bg_color)
    trace_frame.add(@trace_view)
    info_hbox.pack_start(trace_frame, expand: true, fill: true, padding: 5)

    # ==================== DISPLAY AREA ====================
    # Create a drawing area for the CHIP-8 display (below info groups)
    display_frame = create_bold_frame('Display')
    @drawing_area = Gtk::DrawingArea.new
    @drawing_area.set_size_request(@vm.window_width, @vm.window_height)
    # Connect draw signal
    @drawing_area.signal_connect('draw') { |area, cr| on_draw_display(area, cr) }
    display_frame.add(@drawing_area)
    main_vbox.pack_start(display_frame, expand: false, fill: false, padding: 5)

    # Status bar at bottom
    @status_bar = Gtk::Label.new('Ready')
    main_vbox.pack_start(@status_bar, expand: false, fill: false, padding: 5)

    # Show all widgets
    @window.show_all

    # Initial update
    update_display
    update_info_panels
  end

  # Helper to create a Gtk::Frame with a bold label using Pango markup
  def create_bold_frame(title)
    frame = Gtk::Frame.new
    label = Gtk::Label.new
    label.set_markup("<b>#{title}</b>")
    frame.set_label_widget(label)
    frame
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

  def on_load_rom_clicked
    # Stop any running emulation
    @running = false
    @single_step_mode = false

    # Open file chooser dialog
    dialog = Gtk::FileChooserDialog.new(
      title: 'Load ROM File',
      parent: @window,
      action: Gtk::FileChooserAction::OPEN,
      buttons: [
        ['Cancel', Gtk::ResponseType::CANCEL],
        ['Open', Gtk::ResponseType::ACCEPT]
      ]
    )

    # Set filter for binary files
    filter = Gtk::FileFilter.new
    filter.name = 'Binary Files (*.bin, *.rom)'
    filter.add_pattern('*.bin')
    filter.add_pattern('*.rom')
    dialog.add_filter(filter)

    # Also allow all files
    all_filter = Gtk::FileFilter.new
    all_filter.name = 'All Files'
    all_filter.add_pattern('*')
    dialog.add_filter(all_filter)

    if dialog.run == Gtk::ResponseType::ACCEPT
      filename = dialog.filename
      begin
        # Read binary file
        rom_data = File.binread(filename).bytes
        # Load ROM into VM (starts at 0x200 automatically)
        @vm.load_rom(rom_data)
        # Reset VM state but keep the loaded ROM
        @vm.pc = 0x200
        @status_bar.text = "Loaded ROM: #{File.basename(filename)} (#{rom_data.length} bytes)"
        update_info_panels
      rescue => e
        @status_bar.text = "Error loading ROM: #{e.message}"
      end
    end

    dialog.destroy
  end

  def on_save_rom_clicked
    # Stop any running emulation
    @running = false
    @single_step_mode = false

    # Open file chooser dialog
    dialog = Gtk::FileChooserDialog.new(
      title: 'Save ROM File',
      parent: @window,
      action: Gtk::FileChooserAction::SAVE,
      buttons: [
        ['Cancel', Gtk::ResponseType::CANCEL],
        ['Save', Gtk::ResponseType::ACCEPT]
      ]
    )

    # Set filter for binary files
    filter = Gtk::FileFilter.new
    filter.name = 'Binary Files (*.bin)'
    filter.add_pattern('*.bin')
    dialog.add_filter(filter)

    if dialog.run == Gtk::ResponseType::ACCEPT
      filename = dialog.filename
      # Ensure .bin extension if not present
      filename += '.bin' unless filename.end_with?('.bin', '.rom')
      begin
        # Save ROM area (0x200-0xFFF) to binary file
        # Find last non-zero byte to minimize file size
        rom_start = 0x200
        rom_end = 4095  # Max memory size - 1
        # Trim trailing zeros
        while rom_end > rom_start && @vm.read(rom_end) == 0
          rom_end -= 1
        end
        rom_data = @vm.read(rom_start, rom_end - rom_start + 1)
        File.binwrite(filename, rom_data.pack('C*'))
        @status_bar.text = "Saved ROM: #{File.basename(filename)} (#{rom_data.length} bytes)"
      rescue => e
        @status_bar.text = "Error saving ROM: #{e.message}"
      end
    end

    dialog.destroy
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
    text = "Registers:\n\n"
    # Order: PC (4-digit hex), I (4-digit hex), DT (2-digit), ST (2-digit), V0-VF (2-digit each)
    text += "PC: #{@vm.pc.to_s(16).rjust(4, '0').upcase}\n"
    text += "I:  #{@vm.i.to_s(16).rjust(4, '0').upcase}\n"
    text += "DT: #{@vm.delay_timer.to_s(16).rjust(2, '0').upcase}\n"
    text += "ST: #{@vm.sound_timer.to_s(16).rjust(2, '0').upcase}\n"
    # Display V0-VF vertically (one per line)
    16.times do |i|
      text += sprintf("V%X: #{@vm.v[i].to_s(16).rjust(2, '0').upcase}\n", i)
    end
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
    text += "PC: #{@vm.pc.to_s(16).rjust(4, '0').upcase}\n"
    if @vm.pc < 0xFFF
      next_instr = @vm.read_word(@vm.pc)
      text += "Next: 0x#{next_instr.to_s(16).rjust(4, '0').upcase}\n"
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