class Go < Superscript::Dsl
  def go(*args)
    self.say "Go #{args.join(" ")}!"
  end

  def say(message)
    puts message
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
