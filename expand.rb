# utility to process a file that contains RDoc text
# where all indented code is Ruby code to add the output
# of the Ruby lines
# To do: if the input file has extension .rb then
# process only comment lines.

fn = ARGV.shift

txt = File.read(fn)

txt_out = ""

out = StringIO.new


# all the variables used in the code must be defined here
v = w = x = y = z = a = b = fmt = nil

code_out_align = 52
code_out_sep = " -> "

indent = nil
line_num = 0
accum = ""
txt.each do |line|
  line_num += 1
  code = false
  line.chomp!
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
    
    line = $1 if /(.+)#{code_out_sep}.*/.match line
    
    if "(,".include?(line[-1,1])
      accum << line
    else    
      code = accum + line
      accum = ""
      $stdout = StringIO.new
      #$stderr.puts line
      begin
        eval code
        rescue => err
        $stderr.puts "error in line #{line_num}:\n#{line}"
        $stderr.puts "  "+err
      end
      out = $stdout.string
      unless out.empty?
        line << " "*[0,(code_out_align-line.size)].max + code_out_sep + out.chomp
      end     
    end

  end
  txt_out << line + "\n"
end

$stdout = STDOUT
puts txt_out