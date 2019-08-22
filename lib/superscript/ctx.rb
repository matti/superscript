module Superscript
  class Ctx
    def method_missing(*args)
      puts "Error: No such command or variable '#{args.first}'"
      exit 1
    end
  end
end
