class Go < Superscript::Dsl
  def go(*args)
    puts "Go #{args.join(" ")}"
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
