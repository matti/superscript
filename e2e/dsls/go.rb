class Go < Superscript::Dsl
  def go(*args)
    self.say "Go #{args.join(" ")}!"
  end

  def loop &block
    ::Kernel.loop do
      block.call
      sleep 1
    end
  end

  def hang
    sleep 9999
  end

  def say(message)
    puts message
  end

  def struct
    Struct.new(:name).new("joe")
  end

  def now
    Time.now
  end

  def explode!
    asdf
  end

  def exit
    Kernel.exit
  end

  def quit
    exit
  end
end
