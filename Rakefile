# Look in the tasks/setup.rb file for the various options that can be
# configured in this Rakefile. The .rake files in the tasks directory
# are where the options are used.

begin
  require 'bones'
  Bones.setup
rescue LoadError
  load 'tasks/setup.rb'
end

ensure_in_path 'lib'
#require 'float-formats'
require 'float-formats/version'

task :default => 'spec:run'

depend_on 'flt', '1.0.0'
depend_on 'nio', '0.2.4'

PROJ.name = 'float-formats'
PROJ.description = "Floating-Point Formats"
PROJ.authors = 'Javier Goizueta'
PROJ.email = 'javier@goizueta.info'
PROJ.version = Flt::FORMATS_VERSION::STRING
PROJ.rubyforge.name = 'ruby-decimal'
PROJ.url = "http://#{PROJ.rubyforge.name}.rubyforge.org"
PROJ.rdoc.opts = [
  "--main", "README.txt",
  '--title', 'Float-Formats Documentation',
  "--opname", "index.html",
  "--line-numbers",
  "--inline-source"
  ]
depend_on 'nio', '>=0.2.0'

# EOF
