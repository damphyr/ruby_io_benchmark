require 'rubygems'
require 'rake'
levels=["L1","L2","L3"]

levels.each do |l|
  1.upto(10) do |i|
    mkdir_p("src/gen/common/#{l}/C#{i}/inc")
    mkdir_p("src/gen/pc/#{l}/C#{i}/inc")
    mkdir_p("src/hand/common/#{l}/C#{i}/inc")
    mkdir_p("src/hand/pc/#{l}/C#{i}/inc")
    File.open("src/gen/common/#{l}/C#{i}/build.cfg","wb") do |f|
      f.write("prefix=C#{i}\n")
    end
    File.open("src/gen/pc/#{l}/C#{i}/build.cfg","wb") do |f|
      f.write("prefix=C#{i}\n")
    end
    File.open("src/hand/common/#{l}/C#{i}/build.cfg","wb") do |f|
      f.write("prefix=C#{i}\n")
    end
    File.open("src/hand/pc/#{l}/C#{i}/build.cfg","wb") do |f|
      f.write("prefix=C#{i}\n")
    end
    touch("src/hand/pc/#{l}/C#{i}/a.c")
    touch("src/hand/common/#{l}/C#{i}/b.c")
    touch("src/gen/pc/#{l}/C#{i}/c.c")
    touch("src/gen/common/#{l}/C#{i}/d.c")
    touch("src/hand/common/#{l}/C#{i}/C#{i}.h")
    touch("src/hand/pc/#{l}/C#{i}/C#{i}c.h")
  end
end