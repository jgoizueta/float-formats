require 'irb/ruby-lex'
require 'stringio'

class MimickIRB < RubyLex
  attr_accessor :started

  class Continue < StandardError; end
  class Empty < StandardError; end

  def initialize
    super
    set_input(StringIO.new)
  end

  def run(str)
    obj = nil
    @io << str
    @io.rewind
    unless l = lex
      raise Empty if @line == ''
    else
      case l.strip
      when "reset"
        @line = ""
      when "time"
        @line = "puts %{You started \#{IRBalike.started.since} ago.}"
      else
        @line << l << "\n"
        if @ltype or @continue or @indent > 0
          raise Continue
        end
      end
    end
    unless @line.empty?
      obj = eval @line, TOPLEVEL_BINDING
    end
    @line = ''
    @exp_line_no = @line_no

    @indent = 0
    @indent_stack = []

    $stdout.rewind
    output = $stdout.read
    $stdout.truncate(0)
    $stdout.rewind
    [output, obj]
  rescue Object => e
    case e when Empty, Continue
    else @line = ""
    end
    raise e
  ensure
    set_input(StringIO.new)
  end

end


class ExampleExpander
  def initialize(sep=" -> ", align=52)
    @sep = sep
    @align = align    
    @irb = MimickIRB.new
    @output = ""
  end
  def add_line(line)
    line = line.chomp
    line = $1 if /(.+)#{@sep}.*/.match line
    $stdout = StringIO.new
    begin
      out,obj = @irb.run line
      @output << line_output(line,out)
    rescue MimickIRB::Empty
      @output << line_output(line)
    rescue MimickIRB::Continue
      @output << line_output(line)
    rescue Object => e
      msg = "#{e.class}: #{e.message}"
      @output << line_output(line,msg)
      STDERR.puts "#{msg}\n"
    end
    $stdout = STDOUT      
  end
  def output
    @output
  end
  def clear
    @output = ""
  end
  protected
  def line_output(line,output=nil)
    if output
      output = output.chomp
      output = nil if output.strip.empty?
    end
    out = line.dup
    out << " "*[0,(@align-line.size)].max + @sep + output if output
    out << "\n"
    out
  end
end


def expand_text(txt,non_code_block_prefix=nil) # text with indented blocks of code
  exex = ExampleExpander.new
  indent = nil
  
  txt_out = ""
  
  line_num = 0
  accum = ""
  skip_until_blank = false
  txt.each do |line|
    line_num += 1
    code = false
    line.chomp!
        
    if skip_until_blank
      if line.strip.empty?
        skip_until_blank = false
      end
    else
    
      unless line.strip.empty?
        line_indent = /^\s*/.match(line)[0]
        indent ||= line_indent
        indent = line_indent if line_indent.size < indent.size
        if line[line_indent.size,1]=='*'
          inner_indent = /^\s*/.match(line[line_indent.size+1..-1])[0]
          indent += '*'+inner_indent
        else
          if line_indent.size > indent.size
            code = true
          end      
        end
      end
      if code
        exex.add_line line
        line = exex.output.chomp
        exex.clear
      else
        skip_until_blank = true if line[0,1]==non_code_block_prefix
      end
    end
    txt_out << line + "\n"
  end
  txt_out
  
end  

require 'rubygems'

require File.dirname(__FILE__) + '/lib/float-formats'
require File.dirname(__FILE__) + '/lib/float-formats/native.rb'
include Flt

puts expand_text(File.read(ARGV.shift),"[")
