module Superscript
  class Ctx
    def method_missing(*args)
      ::Superscript.error :ctx_method_missing, "No such command or variable '#{args.first}'"
    end
  end
end
