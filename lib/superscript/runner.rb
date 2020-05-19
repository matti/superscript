module Superscript
  def self.error(where, *args)
    puts "-- [ superscript error ] --"
    error_message = ""
    case where
    when :exception
      exception = args.first
      pp exception
      pp exception.backtrace_locations
      error_message = exception
    when :ctx_method_missing, :tp_singleton_method_added, :tp_command_not_found
      error_message = args.first
    when :tp_class_define, :tp_module_define
      error_message = args.first
    else
      pp [:unknown_where, where, args]
      error_message = args.join(" ")
    end

    puts error_message
    if ENV["SUPERSCRIPT_ERROR_EXEC"]
      error_exec_pid = spawn ENV["SUPERSCRIPT_ERROR_EXEC"], error_message
      Process.wait error_exec_pid
    end
    exit 1
  end
  class Runner
    def initialize path=nil
      @path = if path
        path
      else
        "<interactive>"
      end
    end

    def run!(ctx, contents:nil)
      contents = File.read(@path) unless contents

      @armed = false
      trace = TracePoint.new do |tp|
        if ENV["SUPERSCRIPT_DEBUG"]
          p [@armed, tp.path, tp.lineno, tp.method_id, tp.event, tp.defined_class]
        end

        if tp.defined_class&.name == "BasicObject" && tp.method_id == :instance_eval
          if tp.event == :script_compiled
            @armed = true
          elsif tp.event == :c_return
            @armed = false
          end
        end

        if tp.event == :return && tp.defined_class.ancestors.include?(Superscript::Ctx)
          @armed = true
        end

        # when returns to execute our script, always force armed
        if tp.path == @path
          @armed = true
        end

        next unless @armed

        case tp.event
        when :class
          ::Superscript.error :tp_module_define, "Defining modules is not allowed"
        when :line
          lines = if tp.path == "<interactive>"
            contents.split("\n")
          else
            File.read(tp.path).split("\n")
          end

          line = lines[tp.lineno-1].lstrip
          puts "< #{tp.path}:#{tp.lineno-1}"
          puts line
        when :c_call
          # allow calls to these classes
          next if ["Array", "String","Float", "Integer"].include? tp.defined_class.name

          case tp.method_id
          when :singleton_method_added
            trace.disable
            ::Superscript.error :tp_singleton_method_added, "Deffining methods is not allowed"
          else
            trace.disable
            case tp.defined_class.name
            when "Class"
              ::Superscript.error :tp_class_define, "Defining classes is not allowed"
            else
              class_name = case tp.defined_class.inspect
              when "Kernel"
                "Kernel"
              when "Module"
                "Module"
              when "Exception"
                "Exception"
              else
                class_name_matches = tp.defined_class.inspect.match(/^#<.*:(.*)>$/)
                class_name_matches[1]
              end

              command_name = case class_name
              when "Kernel", "Module", "Exception"
                tp.method_id
              else
                "#{class_name}.#{tp.method_id}"
              end

              ::Superscript.error :tp_command_not_found, "Command not found '#{command_name}'"
            end
          end
        when :call
          # disable if calling some other file
          unless tp.path == @path
            @armed = false
          end
          if tp.defined_class.ancestors.include? Superscript::Ctx
            @armed = false
          end
        end
      end

      value = begin
        trace.enable
        v = ctx.instance_eval contents, @path
        trace.disable
        v
      rescue Exception => ex
        case ex.class.to_s
        when "SystemExit"
          exit ex.status
        when "NameError"
          print "#{@path}:#{ex.backtrace_locations.first.lineno} "
          puts ex.message.split(" for ").first
        else
          ::Superscript.error :exception, ex
        end
      ensure
        trace.disable
      end

      value
    end
  end
end
