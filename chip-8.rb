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

    # Create CSS provider for styling
    css_provider = Gtk::CssProvider.new
    css = <<~CSS
      .register-name-label {
        background-color: #ADD8E6;
        border-radius: 4px;
        padding: 2px 4px;
        font-family: Consolas, monospace;
        font-weight: bold;
      }
      .register-value-label {
        font-family: Consolas, monospace;
      }
    CSS
    css_provider.load_from_data(css)
    # Use numeric priority (600 = GTK_STYLE_PROVIDER_PRIORITY_APPLICATION)
    Gtk::StyleContext.add_provider_for_screen(
      Gdk::Screen.default,
      css_provider,
      600
    )

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
    @registers_container = Gtk::Box.new(:vertical, 3)  # Increased vertical spacing
    # Add margin inside the frame (5px on all sides)
    @registers_container.set_margin_start(5)
    @registers_container.set_margin_end(5)
    @registers_container.set_margin_top(5)
    @registers_container.set_margin_bottom(5)
    registers_frame.add(@registers_container)
    info_hbox.pack_start(registers_frame, expand: true, fill: true, padding: 5)

    # Create register labels (name + value pairs)
    @register_labels = {}
    # Order: PC, I, DT, ST, then V0-VF
    create_register_row('PC', @registers_container, bg_color)
    create_register_row(' I', @registers_container, bg_color)  # Leading space for alignment
    create_register_row('DT', @registers_container, bg_color)
    create_register_row('ST', @registers_container, bg_color)
    # V0 through VF
    16.times do |i|
      create_register_row("V#{i.to_s(16).upcase}", @registers_container, bg_color)
    end

    # ----- Stack Group -----
    stack_frame = create_bold_frame('Stack')
    @stack_view = Gtk::TextView.new
    @stack_view.editable = false
    @stack_view.cursor_visible = false
    style_textview(@stack_view, bg_color)
    # Add margin inside the frame (5px on all sides)
    @stack_view.set_margin_start(5)
    @stack_view.set_margin_end(5)
    @stack_view.set_margin_top(5)
    @stack_view.set_margin_bottom(5)
    stack_frame.add(@stack_view)
    info_hbox.pack_start(stack_frame, expand: true, fill: true, padding: 5)

    # ----- Memory Group -----
    memory_frame = create_bold_frame('Memory')
    # Create scrollable window for memory
    @memory_scrolled = Gtk::ScrolledWindow.new
    @memory_container = Gtk::Box.new(:vertical, 3)  # Match registers spacing
    # Add margin inside the frame (5px on all sides)
    @memory_container.set_margin_start(5)
    @memory_container.set_margin_end(5)
    @memory_container.set_margin_top(5)
    @memory_container.set_margin_bottom(5)
    @memory_scrolled.add(@memory_container)
    @memory_scrolled.set_policy(:automatic, :automatic)
    memory_frame.add(@memory_scrolled)
    info_hbox.pack_start(memory_frame, expand: true, fill: true, padding: 5)

    # Populate memory rows (even addresses from 0x200 to 0xFFE)
    @memory_labels = {}
    (0x200..0xFFE).step(2) do |addr|
      create_memory_row(addr, @memory_container, bg_color)
    end

    # ----- Trace Group -----
    trace_frame = create_bold_frame('Trace')
    @trace_view = Gtk::TextView.new
    @trace_view.editable = false
    @trace_view.cursor_visible = false
    style_textview(@trace_view, bg_color)
    # Add margin inside the frame (5px on all sides)
    @trace_view.set_margin_start(5)
    @trace_view.set_margin_end(5)
    @trace_view.set_margin_top(5)
    @trace_view.set_margin_bottom(5)
    trace_frame.add(@trace_view)
    info_hbox.pack_start(trace_frame, expand: true, fill: true, padding: 5)

    # ==================== DISPLAY AREA ====================
    # Create a drawing area for the CHIP-8 display (below info groups)
    display_frame = create_bold_frame('Display')
    @drawing_area = Gtk::DrawingArea.new
    @drawing_area.set_size_request(@vm.window_width, @vm.window_height)
    # Add margin inside the frame (5px on all sides)
    @drawing_area.set_margin_start(5)
    @drawing_area.set_margin_end(5)
    @drawing_area.set_margin_top(5)
    @drawing_area.set_margin_bottom(5)
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

  # Helper to create a register row with name and value labels
  def create_register_row(name, container, bg_color)
    hbox = Gtk::Box.new(:horizontal, 3)
    hbox.set_spacing(3)

    # Name label with light blue rounded background
    name_label = Gtk::Label.new(name)
    name_label.style_context.add_class('register-name-label')
    hbox.pack_start(name_label, expand: false, fill: false, padding: 2)

    # Value label (will be updated)
    value_label = Gtk::Label.new('00')
    value_label.style_context.add_class('register-value-label')
    hbox.pack_start(value_label, expand: false, fill: false, padding: 2)

    container.pack_start(hbox, expand: false, fill: false, padding: 2)

    # Store reference to value label for updates
    @register_labels[name.to_sym] = value_label
  end

  # Helper to create a memory row with address and word value labels
  def create_memory_row(addr, container, bg_color)
    hbox = Gtk::Box.new(:horizontal, 3)  # Match register row spacing
    hbox.set_spacing(3)  # Match register row spacing

    # Address label with light blue rounded background (similar to registers)
    addr_label = Gtk::Label.new(sprintf("0x%04X", addr))  # Removed colon
    addr_label.style_context.add_class('register-name-label')
    hbox.pack_start(addr_label, expand: false, fill: false, padding: 2)

    # Value label showing 2-byte word (will be updated)
    word_value = @vm.read_word(addr)
    value_label = Gtk::Label.new(sprintf("%04X", word_value))
    value_label.style_context.add_class('register-value-label')
    hbox.pack_start(value_label, expand: false, fill: false, padding: 2)

    container.pack_start(hbox, expand: false, fill: false, padding: 2)  # Match register row padding

    # Store reference for updates
    @memory_labels[addr] = value_label
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
    # Update register value labels
    @register_labels[:PC].text = @vm.pc.to_s(16).rjust(4, '0').upcase
    @register_labels[:" I"].text = @vm.i.to_s(16).rjust(4, '0').upcase
    @register_labels[:DT].text = @vm.delay_timer.to_s(16).rjust(2, '0').upcase
    @register_labels[:ST].text = @vm.sound_timer.to_s(16).rjust(2, '0').upcase
    # V0-VF
    16.times do |i|
      reg_name = "V#{i.to_s(16).upcase}".to_sym
      @register_labels[reg_name].text = @vm.v[i].to_s(16).rjust(2, '0').upcase
    end
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
    # Update each memory row's value label
    @memory_labels.each do |addr, label|
      word_value = @vm.read_word(addr)
      label.text = sprintf("%04X", word_value)
    end
  end

  def update_trace_panel
    buffer = @trace_view.buffer
    text = "Instruction Trace:\n\n"
    # Show last few executed instructions (simplified)
    # In a full implementation, would log executed opcodes
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