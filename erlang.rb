# Copyright 2008-2009 Nicolas Charpentier
# Distributed under BSD licence

def extract_version_information(file, type)
  informations = []
  IO.foreach(file) { |line|
    informations << $1 if line =~ /\{#{type},(.*)\}/
  }
  informations[0]
end

def application_modules(app_file)
  modules = FileList.new(app_file.pathmap("%d/*.beam")).pathmap("%f").ext("")
  modules = modules.map {|item| item.gsub(/^([A-Z].*)/, '\'\1\'')}
  modules = "[" + modules.join(', ') + "]"
end

ERL_SOURCES = FileList['lib/*/src/*.erl']
ERL_BEAM = ERL_SOURCES.pathmap("%{src,ebin}X.beam")
ERL_ASN_SOURCES = FileList['lib/*/src/*.asn']

src_to_ebin = "%{src,ebin}X"

ERL_DIRECTORIES = FileList.new('lib/*/src').pathmap(src_to_ebin)

ERL_APPLICATIONS = FileList.new('lib/*/src/*.app.src')\
                            .pathmap(src_to_ebin)

ERL_RELEASE_FILES=FileList.new()
release_files = FileList.new('lib/*/src/*.rel.src')\
                        .pathmap(src_to_ebin)
release_files.each do |d|
  config_file = d.pathmap("%{ebin,src}d/../vsn.config")
  vsn = extract_version_information(config_file,"release_name")
  map_expression = "%X-" + vsn.gsub(/\"/,"")  + ".rel"
  ERL_RELEASE_FILES.add d.pathmap(map_expression)
end

ERL_BOOT_FILES = ERL_RELEASE_FILES.pathmap("%{src,ebin}X.boot")
ERL_RELEASE_ARCHIVES = ERL_RELEASE_FILES.pathmap("distribs/%f")\
                                        .ext(".tar.gz")

ERL_RELEASE_ARCHIVES.each do |d|
  CLEAN.include d
end

directory "distribs"

CLEAN.include "targets"

ERL_DIRECTORIES.each do |d| 
  directory d
  CLEAN.include d
end



rule ".beam" =>  ["%{ebin,src}X.erl"] do |t|
  output = t.name.pathmap("%d")
  sh "#{ERL_TOP}/bin/erlc -Ilib #{ERLC_FLAGS} -o #{output} #{t.source}"
end

rule '.app' => ["%{ebin,src}X.app.src",
                "%{ebin,src}d/../vsn.config"] do |t|
  configuration = t.name.pathmap("%d/../vsn.config")
  vsn = extract_version_information(configuration,"vsn")
  modules = application_modules t.name
  File.open(t.name, 'w') do |outf|
    File.open(t.source) do |inf|
      inf.each_line do |ln|
        outf.write(ln.gsub('%VSN%', vsn).gsub('%MODULES%',modules))
      end
    end
  end
end

rule ".rel" => [proc {|a| a.split('-')[0..-2].join('-')\
                  .pathmap("%{ebin,src}X.rel.src")}] do |t|

  configuration = t.name.pathmap("%d/../vsn.config")
  release_name = extract_version_information(configuration,"release_name")
  output = t.name.pathmap("%X.rel")
  sh "#{ERL_TOP}/bin/escript scripts/make_release_file "\
     "#{t.source} #{output} #{release_name} #{ERL_DIRECTORIES}" 
end

rule ".boot" => [".rel"] do |t|
  output = t.name.pathmap("%d")
  source = t.source.ext("")
  script = "scripts/make_script"
  sh "#{ERL_TOP}/bin/escript #{script} distribs #{source} #{output} #{ERL_DIRECTORIES}"
end

rule ".tar.gz" => [proc {|a|
                     FileList.new(a.ext("").ext("")\
                                  .pathmap("lib/*/ebin/%f.rel"))},
                   "distribs"] do |t|
  source = t.source.ext("")
  script = "scripts/make_release"
  sh "#{ERL_TOP}/bin/escript #{script} #{source} distribs without "\
  "#{ERL_TOP} #{ERL_DIRECTORIES}"
end

ERL_ASN_SOURCES.each do |source|
  hrl = source.pathmap("%X.hrl")
  erl = source.pathmap("%X.erl")
  beam = erl.pathmap("%{src,ebin}X.beam")
  asndb = source.pathmap("%X.asn1db")
  file hrl => source do
    sh "#{ERL_TOP}/bin/erlc +noobj -Ilib #{ERLC_FLAGS} -o #{hrl.pathmap("%d")} #{source}"
    sh "#{ERL_TOP}/bin/erlc -Ilib #{ERLC_FLAGS} -o #{beam.pathmap("%d")} #{erl}"
  end
  file erl => source do
    sh "#{ERL_TOP}/bin/erlc +noobj -Ilib #{ERLC_FLAGS} -o #{hrl.pathmap("%d")} #{source}"
    sh "#{ERL_TOP}/bin/erlc -Ilib #{ERLC_FLAGS} -o #{beam.pathmap("%d")} #{erl}"
  end
  file asndb => source do
    sh "#{ERL_TOP}/bin/erlc +noobj -Ilib #{ERLC_FLAGS} -o #{asndb.pathmap("%d")} #{source}"
    sh "#{ERL_TOP}/bin/erlc -Ilib #{ERLC_FLAGS} -o #{beam.pathmap("%d")} #{erl}"
  end
  CLEAN.include hrl
  CLEAN.include asndb
  CLEAN.include erl
  CLEAN.include beam
end

def check_dependencies (beam, file)
  dependencies = []
  ## Commenté, casse le multi projet
  #IO.foreach(file) { |line|
  #  header = file.pathmap("%d/#$1") if 
  #  line =~ /^-include\("(.*)"\)/
  #  if header 
  #    dependencies << "#{beam}: #{header}" 
  #    dependencies <<  check_dependencies(beam, header)
  #  end
  #} if File.file?(file)
  #dependencies.flatten
end

def erlang_include_dependencies
  FileList['lib/*/src/*.erl'].collect { |file|
    beam = file.pathmap("%{src,ebin}X.beam")
    check_dependencies(beam, file).uniq
  }.flatten
end

file ".depend_erlang.mf" => ERL_SOURCES do
  File.open(".depend_erlang.mf",'w') {|file| 
    erlang_include_dependencies.each do |l|
      file.write("#{l}\n")
    end
  }
end

CLEAN.include ".depend_erlang.mf"

desc "Compile Erlang sources"
task :erlang_modules => ERL_DIRECTORIES + ERL_BEAM

desc "Build application resource file"
task :erlang_applications => [:erlang_modules] + ERL_APPLICATIONS

desc "Build erlang boot files"
task :erlang_release_files => [:erlang_applications] + 
  ERL_RELEASE_FILES  + ERL_BOOT_FILES

desc "Build release tarball"
task :erlang_releases => [:erlang_release_files] + ERL_RELEASE_ARCHIVES

desc "Build release tarball with erts"
task :erlang_target_systems, :n, :needs=> [:erlang_release_files] +
  ERL_RELEASE_ARCHIVES do |t, args|
  source = FileList.new("lib/*/ebin/#{args.n}*.rel").ext("")
  mkdir "targets" rescue has_errors = true
  script = "scripts/make_release"
  sh "#{ERL_TOP}/bin/escript #{script} #{source} targets with "
  "#{ERL_TOP} #{ERL_DIRECTORIES}"
end

CLEAN.include "lib/*/doc/*.html"
CLEAN.include "lib/*/doc/*.css"
CLEAN.include "lib/*/doc/*.png"
CLEAN.include "lib/*/doc/edoc-info"

desc "Buid Application documentation"
task :edoc, :name, :needs => [:erlang_applications] do |t,args|
  script = "scripts/make_doc"
  sh "#{ERL_TOP}/bin/escript #{script} #{args.name} #{ERL_DIRECTORIES}"
end

desc "Buid all application documentation"
task :edocs => [:erlang_applications] do |t,args|
  ERL_APPLICATIONS.each do |application|
    name = application.pathmap("%f").ext("")
    script = "scripts/make_doc"
    sh "#{ERL_TOP}/bin/escript #{script} #{name} #{ERL_DIRECTORIES}"
  end
end

desc "Run dialyzer"
task :dialyzer do
  sh "#{ERL_TOP}/bin/dialyzer --src -c #{ERL_DIRECTORIES.pathmap("%{ebin,src}X")}"
end

desc "Compile all project"
task :compile => [ :erlang_applications ]

task :run, :name, :node, :needs => [ :compile ] do |t,args|
  node = args.node || "node"
  paths = ERL_DIRECTORIES.join(" -pa ")
  sh "erl -boot start_sasl -pa #{paths} -sname #{args.node} -s #{args.name} start "
end