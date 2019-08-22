module Superscript
  class Runner
    def initialize path=nil
      @path = if path
        path
      else
        "<interactive>"
      end
    end

    def run!(ctx:nil, contents:nil)
      contents = File.read(@path) unless contents
      ctx = Superscript::Ctx.new unless ctx

      @armed = false
      trace = TracePoint.new do |tp|
        if ENV["SUPERSCRIPT_DEBUG"]
          p [@armed, tp.path, tp.lineno, tp.method_id, tp.event, tp.defined_class]
        end

        if tp.defined_class.name == "BasicObject" && tp.method_id == :instance_eval
          if tp.event == :script_compiled
            @armed = true
          elsif tp.event == :c_return
            @armed = false
          end
        end

        if tp.event == :return && tp.defined_class.name == "Superscript::Ctx"
          @armed = true
        end

        next unless @armed

        case tp.event
        when :line
          puts "< " + contents.split("\n")[tp.lineno - 1]
        when :c_call
          next if ["String","Float", "Integer"].include? tp.defined_class.name
          case tp.method_id
          when :singleton_method_added
            puts "Error: Deffining methods is not allowed"
            trace.disable
            exit 1
          else
            puts "Error: Command not found '#{tp.method_id}'"
            trace.disable
            exit 1
          end
        when :call
          if tp.defined_class.name == "Superscript::Ctx"
            @armed = false
          end
        end
      end

      value = begin
        trace.enable
        ctx.instance_eval contents, @path
        trace.disable
      rescue Exception => ex
        case ex.class.to_s
        when "SystemExit"
          exit ex.status
        when "NameError"
          print "#{@path}:#{ex.backtrace_locations.first.lineno} "
          puts ex.message.split(" for ").first
        else
          p [:exception, ex]
        end
      ensure
        trace.disable
      end

      value
    end
  end
end
