require 'rubygems'
require 'rake'
#Class to encapsulate scanning methods and perform lazy eval and caching of results
class Scanner
  attr_reader :base_dir
  #Initialize the scanner with the directory it should work from
  def initialize current_dir,configuration
    @current_dir=current_dir
    @configuration=configuration
    @base_dir=File.expand_path(@configuration['base_dir'])
    @base_src=File.join(@base_dir,'src')
  end
  #All C files
  def sources
    @sources||=FileList["#{@current_dir}/**/*.c"]
    return @sources
  end
  #All .h files
  def headers
    @headers||=FileList["#{@current_dir}/**/*.h"]
    return @headers
  end
  #All C code files
  def sources_and_headers
    return self.sources+self.headers
  end
  #This actually determines which components will be build
  #and it does so by looking for the BUILD_CONFIG_FILE named files
  #The convention is that there will be one for each component
  #It will return a FileList with the directories under hand/ containing
  #a configuration file
  def component_paths platform
    @component_paths||={} 
    @component_paths['pc']||=FileList["#{@current_dir}/**/build.cfg"].exclude(/\/gen\//,/\/dsl\//,/\/programs\//,/\/mocks\//,/\/common/).pathmap('%d')
    @component_paths['common']||=FileList["#{@current_dir}/**/build.cfg"].exclude(/\/gen\//,/\/dsl\//,/\/programs\//,/\/mocks\//).pathmap('%d')
    return @component_paths[platform]+@component_paths['common']
  end
  #Returns the Layer/Name portions of the component paths
  def component_names platform
    @component_names={}
    @component_names['pc']||=FileList["#{@current_dir}/**/build.cfg"].exclude(/\/gen\//,/\/dsl\//,/\/programs\//,/\/mocks\//,/\/common/).pathmap('%-2d')
    @component_names['common']||=FileList["#{@current_dir}/**/build.cfg"].exclude(/\/gen\//,/\/dsl\//,/\/programs\//,/\/mocks\//,/\/pc/).pathmap('%-2d')
    return @component_names[platform]+@component_names['common']
  end
  #Returns a list of all the generated interface directories
  def interfaces
    if @current_dir=~/\/interfaces.*$/
      @interfaces||=FileList["#{@current_dir}/**/build.cfg"].pathmap("%d")
    else
      @interfaces||=FileList["#{@current_dir}/**/interfaces/**/build.cfg"].pathmap("%d")
    end
    return @interfaces
  end
  #The sources for a component are determined as follows:
  #
  #The files under hand/<platform>/<layer>/<component>
  #
  #The files under hand/common/<layer>/<component>
  #
  #The files under gen/<platform>/<layer>/<component>
  #
  #The files under gen/common/<layer>/<component>
  def component_sources component,platform
    @component_sources||={}
    hp_dir=File.join(@base_dir,'src','hand',platform,component)
    hc_dir=File.join(@base_dir,'src','hand','common',component)
    gp_dir=File.join(@base_dir,'src','gen',platform,component)
    gc_dir=File.join(@base_dir,'src','gen','common',component)
    @component_sources["#{component}_#{platform}"]||=FileList["#{hp_dir}/*.c","#{hc_dir}/*.c","#{gp_dir}/*.c","#{gc_dir}/*.c"]
    return @component_sources["#{component}_#{platform}"]
  end
  #The headers for a component are determined as follows:
  #
  #The files under hand/<platform>/<layer>/<component>
  #
  #The files under hand/common/<layer>/<component>
  #
  #The files under gen/<platform>/<layer>/<component>
  #
  #The files under gen/common/<layer>/<component>
  #
  #The files under hand/<platform>/<layer>/<component>/inc
  #
  #The files under hand/common/<layer>/<component>/inc
  #
  #The files under gen/<platform>/<layer>/<component>/inc
  #
  #The files under gen/common/<layer>/<component>/inc
  def component_headers component,platform
    @component_headers||={}
    hp_dir=File.join(@base_dir,'src','hand',platform,component)
    hc_dir=File.join(@base_dir,'src','hand','common',component)
    gp_dir=File.join(@base_dir,'src','gen',platform,component)
    gc_dir=File.join(@base_dir,'src','gen','common',component)
    hp_dir_inc=File.join(@base_dir,'src','hand',platform,component,'inc')
    hc_dir_inc=File.join(@base_dir,'src','hand','common',component,'inc')
    gp_dir_inc=File.join(@base_dir,'src','gen',platform,component,'inc')
    gc_dir_inc=File.join(@base_dir,'src','gen','common',component,'inc')
    @component_headers["#{component}_#{platform}"]||=FileList["#{hp_dir}/*.h","#{hc_dir}/*.h","#{gp_dir}/*.h","#{gc_dir}/*.h",
      "#{hp_dir_inc}/*.h","#{hc_dir_inc}/*.h","#{gp_dir_inc}/*.h","#{gc_dir_inc}/*.h"]
      return @component_headers["#{component}_#{platform}"]
    end
  end
  
def setup_build_tasks scanner,configuration
  platform='pc'
  out_dir= File.join(configuration['out_dir'],platform)
  components=scanner.component_names(platform)
  interfaces=scanner.interfaces
  puts "Creating component build tasks"
  components.each do |comp|
    component_build_task(comp,platform,out_dir,scanner,configuration)
  end
end

def component_build_task component,platform,out_dir,scanner,configuration
  #get the component build configuration
  cfg=read_component_configuration(component,platform,configuration)
  if cfg && !cfg.empty?
    #get the  sources
    srcs=scanner.component_sources(component,platform)
    #and the include directories
    component_dir=File.join(configuration['base_dir'],'src','hand',platform,component)
    incs=includes(component_dir,platform,cfg)
    output_dir=File.join(out_dir,"#{cfg['prefix']}")
    lib=File.join(output_dir,"#{cfg['prefix']}.lib")
    return lib
  else
    puts "No configuration file in #{component_dir}. Skipped!"
  end
end#if $configuration
#Reads a configuration file and returns a hash with the
#configuration as key-value pairs
def read_configuration filename
  puts "Reading configuration from #{filename}"
  lines=File.readlines(filename)
  cfg={}
  #change in the dir of the file to calculate paths correctly
  cfg_dir=File.dirname(filename)
  lines.each do |l|
    l.gsub!("\t","")
    l.chomp!
    #ignore if it starts with a hash
    unless l=~/^#/ || l.empty?
      #clean up by trimming whitespaces
      l.gsub!(/\s*=\s*/,'=')
      l.gsub!(/\s*,\s*/,',')
      #
      if l=~/=$/
        trailing_equals=true
      end
      #split on equals
      fields=l.split('=')
      #more than one part needed
      if fields.size>1
        #the key is the first
        key=fields.first
        #take the key out of the array
        values=fields.drop(1)
        #the value to each key is the values array joined with space
        case key 
        when "include","depend","interface","external" 
          cfg[key]||=[]
          #here we want to handle a comma separated list of prefixes
          incs=values.join
          cfg[key]+=incs.split(',')
          cfg[key].uniq!
        when "out_dir","base_dir","model" 
          cfg[key]=File.expand_path(File.join(cfg_dir,values.join))
        else
          cfg[key]=values.join('=')
        end#case
        cfg[key]<<'=' if trailing_equals
      else
        puts "ERROR - Configuration syntax error in #{filename}:\n'#{l}'"
      end#if size>1
    end#unless
  end#lines.each
  return cfg
end

#reads the configuration files for the gen/ and hand/ portions of a component
#merges them and returns the result
def read_component_configuration component,platform,configuration
  hp_dir=File.join(configuration['base_dir'],'src','hand',platform,component)
  hc_dir=File.join(configuration['base_dir'],'src','hand','common',component)
  gp_dir=File.join(configuration['base_dir'],'src','gen',platform,component)
  gc_dir=File.join(configuration['base_dir'],'src','gen','common',component)
  cfg={}
  [hp_dir,hc_dir,gp_dir,gc_dir].each do |cfg_dir|
    file_to_merge=File.join(cfg_dir,'build.cfg')
    if File.exists?(file_to_merge)
      cfg_to_merge=read_configuration(file_to_merge)
      cfg=merge_configurations(cfg,cfg_to_merge) 
    end
  end
  return cfg
end

#Merges two build.cfg files
def merge_configurations cfg,cfg2
  cfg['prefix']||=cfg2['prefix']
  raise "Attempting to merge configurations with differing prefixes: '#{cfg['prefix']}' vs. '#{cfg2['prefix']}' " if cfg['prefix']!=cfg2['prefix']
  cfg['include']||=[]
  cfg['depend']||=[]
  cfg['interface']||=[]
  cfg['include']+=cfg2['include'] if cfg2['include']
  cfg['depend']+=cfg2['depend'] if cfg2['depend']
  cfg['interface']+=cfg2['interface'] if cfg2['interface']
  return cfg
end

def includes current_dir,platform,cfg
  incs=[]
  if $configuration
    base_dir= $configuration['base_dir']
    base_src= File.join("#{$configuration['base_dir']}",'src')
    #always the inc directory and the globals
    inc_dir=File.join(current_dir,'inc')
    incs=[inc_dir,
      inc_dir.gsub("/hand","/gen"),
      inc_dir.gsub("/#{platform}","/common"),
      inc_dir.gsub("/hand","/gen").gsub("/#{platform}","/common"),
      current_dir,
      current_dir.gsub("/hand","/gen"),
      current_dir.gsub("/#{platform}","/common"),
      current_dir.gsub("/hand","/gen").gsub("/#{platform}","/common"),
      File.join(base_src,'gen/common/GLOBALS'),
      File.join(base_src,'hand/common/GLOBALS'),
      File.join(base_src,"hand/#{platform}/GLOBALS"),
      File.join(base_src,"hand/#{platform}/GLOBALS")
    ]
    #and now the dependencies
    incs+=includes_from_configuration(current_dir,platform,cfg)
  end
  return incs.uniq
end