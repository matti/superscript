Signal.trap "TERM" do
  exit 0
end

module Superscript
  class Runner
    def initialize path=nil, opts={}
      @methods = opts[:methods] || false
      @on_error_exec = opts[:on_error_exec]

      @armed = false
      @path = if path
        path
      else
        "<interactive>"
      end
    end

    def error!(where, *args)
      puts "-- [ superscript error ] --"
      error_message = ""
      case where
      when :exception
        exception = args.first
        error_message = exception
      when :tp_call_superscript, :tp_call_superscript_global
        error_message = "Can't touch this"
      when :ctx_method_missing, :tp_singleton_method_added, :tp_command_not_found
        error_message = args.first
      when :tp_class_define, :tp_module_define
        error_message = args.first
      else
        pp [:unknown_where, where, args]
        error_message = args.join(" ")
      end

      puts error_message
      if @on_error_exec
        system("#{@on_error_exec} #{error_message}")
      end
      exit 1
    end

    def arm!(reason=nil)
      p [:arm!, reason] if ENV["SUPERSCRIPT_DEBUG"]
      @armed = true
    end
    def disarm!(reason=nil)
      p [:disarm!, reason] if ENV["SUPERSCRIPT_DEBUG"]
      @armed = false
    end

    def run!(ctx, contents:nil)
      contents = File.read(@path) unless contents
      $__superscript_none_of_yer_business = self
      ctx.define_singleton_method "method_missing" do |*args|
        $__superscript_none_of_yer_business.error! :ctx_method_missing, "No such command or variable '#{args.first}'"
      end

      disarm! :at_start
      trace = TracePoint.new do |tp|
        if ENV["SUPERSCRIPT_DEBUG"]
          p [@armed, tp.path, tp.lineno, tp.method_id, tp.event, tp.defined_class]
        end

        if tp.event == :line && tp.path == @path && !@armed
          arm!
        end

        if tp.defined_class&.name == "BasicObject" && tp.method_id == :instance_eval
          if tp.event == :script_compiled
            arm! :script_compiled
          elsif tp.event == :c_return
            disarm! :script_done
          end
        end

        if tp.path == @path && tp.event == :return && tp.defined_class.ancestors.include?(Superscript::Ctx)
          arm! :return_to_script_from_dsl_calling_another_dsl_method
        end

        next unless @armed

        case tp.event
        when :class
          error! :tp_module_define, "Defining modules is not allowed"
        when :line
          lines = if tp.path == "<interactive>"
            contents.split("\n")
          else
            File.read(tp.path).split("\n")
          end

          line = lines[tp.lineno-1].lstrip
          puts "< #{tp.path}:#{tp.lineno-1}"
          puts line

          if line.match(/\$__superscript_none_of_yer_business/)
            tp.disable
            error! :tp_call_superscript_global
          end
        when :c_call
          # allow calls to these instances
          if tp.defined_class.ancestors.at(1) == Struct
            disarm! :safe_instance
            next
          end
          if ["Array", "String","Float", "Integer"].include? tp.defined_class.name
            disarm! :safe_instance
            next
          end

          case tp.method_id
          when :singleton_method_added
            if @methods
              next
            end
            trace.disable
            error! :tp_singleton_method_added, "Deffining methods is not allowed"
          when :method_missing
            trace.disable
          else
            trace.disable
            case tp.defined_class.name
            when "Class"
              error! :tp_class_define, "Defining classes is not allowed"
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

              error! :tp_command_not_found, "Command not found '#{command_name}'"
            end
          end
        when :call
          if tp.method_id == :method_missing
            tp.disable
            next
          end

          if tp.defined_class.ancestors.first.to_s == "#<Class:Superscript>"
            tp.disable
            error! :tp_call_superscript
          end
          # disable if calling some other file
          # but do not allow call to Superscript.error etc
          if tp.path != @path
            disarm! :calling_other_file
          end
          tp.defined_class.ancestors.each do |ancestor|
            if ancestor.to_s == "Superscript::Dsl"
              disarm! :dsl_method
              break
            end
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
          error! :exception, ex
        end
      ensure
        trace.disable
      end

      value
    end
  end
end
