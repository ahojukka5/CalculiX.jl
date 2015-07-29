# This file is a part of JuliaFEM/CalculiX.jl.
# License is MIT: see https://github.com/JuliaFEM/CalculiX.jl/blob/master/LICENSE.md

here = dirname(@__FILE__)

src = joinpath(here,"src")
downloads = joinpath(here,"downloads")
builds = joinpath(here,"builds")
usr = joinpath(here,"usr")
include = joinpath(usr,"include")
lib = joinpath(usr,"lib")
spooles = joinpath(src,"spooles")
src_arpack = joinpath(src,"ARPACK")
build_arpack = joinpath(builds,"ARPACK")
src_calculix = joinpath(src,"CalculiX-cmake")
build_calculix = joinpath(builds,"CalculiX")
dirs = [src downloads builds usr include lib spooles build_arpack build_calculix]

for dir in dirs
  try
    mkdir(dir)
  end
end

cd(downloads)
if !isfile(joinpath(downloads,"spooles.2.2.tgz"))
  run(`wget http://netlib.sandia.gov/linalg/spooles/spooles.2.2.tgz`)
end
cd(spooles)
run(`tar xzf ../../downloads/spooles.2.2.tgz`)

# See tutorial here http://www.libremechanics.com/?q=node/9
#First fix of spooles
println(pwd())
run(`mv Tree/src/makeGlobalLib Tree/src/old_makeGlobalLib`)
in = open("Tree/src/old_makeGlobalLib","r")
out = open("Tree/src/makeGlobalLib","w")
for line in readlines(in)
  if ismatch(r"drawTree",line)
    write(out,"      draw.c \\\n")
  else
    write(out,line)
  end
end
close(in)
close(out)

# Second fix of spooles = gcc compiler
run(`mv Make.inc old_Make.inc`)
in = open("old_Make.inc","r")
out = open("Make.inc","w")
for line in readlines(in)
  if ismatch(r"/usr/lang-4.0/bin/cc",line)
    write(out,"  CC = gcc\n")
    write(out,"# CC = /usr/lang-4.0/bin/cc\n")
  else
    write(out,line)
  end
end
close(in)
close(out)

# Let's try to build spools
if !isfile(joinpath(lib,"libspooles.a"))
  run(`make lib`)
  run(`mv spooles.a $lib/libspooles.a`)
  #println(pwd())
  run(`cp misc.h FrontMtx.h	SymbFac.h $include`)
  try
    mkdir(joinpath(include,"spooles"))
    mkdir(joinpath(include,"misc"))
    mkdir(joinpath(include,"FrontMtx"))
    mkdir(joinpath(include,"SymbFac"))
  end
  run(`cp misc.h FrontMtx.h	SymbFac.h $include/spooles`)
  run(`cp misc.h $include/misc`)
  run(`cp FrontMtx.h $include/FrontMtx`)
  run(`cp SymbFac.h $include/SymbFac`)
end
cd(joinpath(spooles,"MT","src"))
if !isfile(joinpath(lib,"libspoolesMT.a"))
  run(`make`)
  run(`mv spoolesMT.a $lib/libspoolesMT.a`)
  run(`cp ../spoolesMT.h $include`)
  try
    mkdir(joinpath(include,"spooles","MT"))
  end
  run(`cp ../spoolesMT.h $include/spooles/MT`)
end

# Next ARPACK
cd(downloads)
if !isfile(joinpath(downloads,"arpack96.tar.gz"))
  run(`wget http://www.caam.rice.edu/software/ARPACK/SRC/arpack96.tar.gz`)
  run(`wget http://www.caam.rice.edu/software/ARPACK/SRC/patch.tar.gz`)
end

cd(src)
run(`tar xzf ../downloads/arpack96.tar.gz`)
run(`tar xzf ../downloads/patch.tar.gz`)

cd(src_arpack)
run(`mv ARmake.inc old_ARmake.inc`)
in = open("old_ARmake.inc","r")
out = open("ARmake.inc","w")
for line in readlines(in)
  if ismatch(r"home = ",line)
    write(out,"home = $src_arpack\n")
  elseif ismatch(r"PLAT = SUN4",line)
    write(out,"PLAT = linux\n")
  elseif ismatch(r"FC      = f77",line)
    write(out,"FC = gfortran\n")
  elseif ismatch(r"FFLAGS	= -O -cg89",line)
    write(out,"FFLAGS = -O2\n")
  elseif ismatch(r"MAKE    = /bin/make",line)
    write(out,"MAKE = make\n")
  else
    write(out,line)
  end
end
close(in)
close(out)

cd(joinpath(src_arpack,"UTIL"))
run(`mv second.f old_second.f`)
in = open("old_second.f","r")
out = open("second.f","w")
for line in readlines(in)
  if ismatch(r"EXTERNAL           ETIME",line)
    write(out,"*\n")
  else
    write(out,line)
  end
end
close(in)
close(out)

cd(src_arpack)
# and let's try to build
if !isfile(joinpath(lib,"libarpack.a"))
  run(`make lib`)
  run(`mv libarpack_linux.a $lib/libarpack.a`)
end

# Finally let's add all the headers to the include directory
run(`find . -name '*.h' -exec cp --parents \{\} ../usr/include/ \;`)

# And then the Calculix package
cd(src)
run(`git clone git@github.com:JuliaFEM/CalculiX-cmake.git`)
cd(build_calculix)
run(`cmake ../../src/CalculiX-cmake`)
run(`make`)
#run(`mv libcalculix.so $lib`)


# using BinDeps

# @BinDeps.setup
# spooles = "spooles.2.2"
# libspooles = library_dependency("libspooles", aliases = ["libspooles.so"])
# sources = provides(Sources,URI("http://netlib.sandia.gov/linalg/spooles/spooles.2.2.tgz"),libspooles,unpacked_dir="dummy_name_here")
# builddir = joinpath(BinDeps.builddir(libspooles),libspooles.name)
# srcdir = joinpath(BinDeps.srcdir(libspooles),spooles)
# libdir = joinpath(BinDeps.depsdir(libspooles),"usr","lib")
# includedir = joinpath(BinDeps.depsdir(libspooles),"usr","include")

# provides(SimpleBuild,
#          (@build_steps begin
#             GetSources(libspooles)
#             CreateDirectory(builddir)
#             CreateDirectory(libdir)
#             CreateDirectory(includedir)
#             (@build_steps begin
#                ChangeDirectory(builddir)
#                println(pwd())
#                run(`mkdir spooles`)
#                run(`mv src/* spooles`)
#                run(`mv spooles src`)
#              end)
#           end),libspooles, os = :Unix)

# @BinDeps.install Dict( :libspooles => :libspooles)