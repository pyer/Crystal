class IO::FileDescriptor < IO
  # Yields `self` to the given block, disables character echoing for the
  # duration of the block, and returns the block's value.
  #
  # This will prevent displaying back to the user what they enter on the terminal.
  #
  # Raises `IO::Error` if this `IO` is not a terminal device.
  #
  # ```
  # print "Enter password: "
  # password = STDIN.noecho &.gets.try &.chomp
  # puts
  # ```
  def noecho(& : self -> _)
    system_echo(false) { yield self }
  end

  # Yields `self` to the given block, enables character echoing for the
  # duration of the block, and returns the block's value.
  #
  # This causes user input to be displayed as they are entered on the terminal.
  #
  # Raises `IO::Error` if this `IO` is not a terminal device.
  def echo(& : self -> _)
    system_echo(true) { yield self }
  end

  # Disables character echoing on this `IO`.
  #
  # This will prevent displaying back to the user what they enter on the terminal.
  #
  # Raises `IO::Error` if this `IO` is not a terminal device.
  def noecho! : Nil
    system_echo(false) { return }
  end

  # Enables character echoing on this `IO`.
  #
  # This causes user input to be displayed as they are entered on the terminal.
  #
  # Raises `IO::Error` if this `IO` is not a terminal device.
  def echo! : Nil
    system_echo(true) { return }
  end

  # Yields `self` to the given block, enables character processing for the
  # duration of the block, and returns the block's value.
  #
  # The so called cooked mode is the standard behavior of a terminal,
  # doing line wise editing by the terminal and only sending the input to
  # the program on a newline.
  #
  # Raises `IO::Error` if this `IO` is not a terminal device.
  def cooked(& : self -> _)
    system_raw(false) { yield self }
  end

  # Yields `self` to the given block, enables raw mode for the duration of the
  # block, and returns the block's value.
  #
  # In raw mode every keypress is directly sent to the program, no interpretation
  # is done by the terminal. On Windows, this also enables ANSI input escape
  # sequences.
  #
  # Raises `IO::Error` if this `IO` is not a terminal device.
  def raw(& : self -> _)
    system_raw(true) { yield self }
  end

  # Enables character processing on this `IO`.
  #
  # The so called cooked mode is the standard behavior of a terminal,
  # doing line wise editing by the terminal and only sending the input to
  # the program on a newline.
  #
  # Raises `IO::Error` if this `IO` is not a terminal device.
  def cooked! : Nil
    system_raw(false) { return }
  end

  # Enables raw mode on this `IO`.
  #
  # In raw mode every keypress is directly sent to the program, no interpretation
  # is done by the terminal. On Windows, this also enables ANSI input escape
  # sequences.
  #
  # Raises `IO::Error` if this `IO` is not a terminal device.
  def raw! : Nil
    system_raw(true) { return }
  end

end
