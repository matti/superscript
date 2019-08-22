module Superscript
  class Ctx
    def method_missing(*args)
      puts "Error: No such command or variable '#{args.first}'"
      exit 1
    end

    def go *args
      puts "Go #{args.join(" ")}!"
    end

    def wait seconds_or_random_range
      amount = if seconds_or_random_range.is_a? Range
        rand(seconds_or_random_range)
      else
        seconds_or_random_range
      end

      sleep amount
    end

    def exit
      Kernel.exit
    end
    def quit
      exit
    end
  end
end
