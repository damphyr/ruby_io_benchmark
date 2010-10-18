require 'engine'
require 'benchmark'
configuration={'base_dir'=>File.join(File.dirname(__FILE__),'..'),
  'out_dir'=>File.join(File.dirname(__FILE__),'..','build')}
scanner=Scanner.new(File.join(File.dirname(__FILE__),'..'),configuration)
puts '*'*74
puts Benchmark.measure{setup_build_tasks(scanner,configuration)}