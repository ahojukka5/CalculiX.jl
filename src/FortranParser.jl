using FactCheck

function pushcleanedargs!(arglist,inputstring)
    for arg in split(strip(inputstring),",")
        cleaned_arg = strip(arg)
        if cleaned_arg != ""
            cleaned_arg = split(cleaned_arg,"(")[1]
            if ismatch(r"\)",cleaned_arg)
                continue
            end
            push!(arglist,cleaned_arg);
        end
    end
end

test_clean1 = "a,b,c"
test_clean2 ="typeboun(*),inpc(*)"
test_output = []
test_output2 = []
facts("Testing pushcleanedargs!(arglist,inputstring)") do
    pushcleanedargs!(test_output,test_clean1)
    @fact test_output --> ["a","b","c"]
    pushcleanedargs!(test_output2,test_clean2)
    @fact test_output2 --> ["typeboun","inpc"]
end

function find_subroutine_args(file_lines)
    activeline = false
    subroutineargs = []
    #fil = open(file_name)

    for line in file_lines
        if activeline & ismatch(r"\)",line)
            activeline = false
            line_middle_part = split(split(line,"&")[2],")")[1]
            pushcleanedargs!(subroutineargs,line_middle_part)
        end
        if activeline
            line_end_part = split(line,"&")[2]
            pushcleanedargs!(subroutineargs,line_end_part)
        end
        if ismatch(r"subroutine",line)
            activeline = true
            line_end_part = split(line,"(")[2]
            pushcleanedargs!(subroutineargs,line_end_part)
        end
    end
    #close(fil)
    return subroutineargs
end

test_data1 = ["      subroutine calinput(co,nk,"
              "     &  ne,nodeboun)"
              "! comment line"]

facts("Testing find_subroutine_args(file_lines)") do
    @fact find_subroutine_args(test_data1) --> ["co","nk","ne","nodeboun"]
end

function findalldefinitions(file_lines)
    activeline = false
    continuecomp = "empty"
    #fil = open(file_name)
    output = Dict()
    keyw = ["logical" "character" "integer" "real"]
    #for key in keyw
    #    output[key] = []
    #end
    for line in file_lines
        if activeline
            if ismatch(r"\&",line)
                #println(line)
                m = match(r"(\s*&\s+)(.*)",line)
                pushcleanedargs!(output[continuecomp],m.captures[2])
            else
                activeline = false
            end
        end
        for comp in keyw
            if ismatch(Regex(comp),line)
                activeline = true
                m = match(r"(\s*\w+\s+)(.*)",line)
                if ~(comp in keys(output))
                    output[comp] = []
                end
                pushcleanedargs!(output[comp],m.captures[2])
                continuecomp = comp
            end
        end
    end
    #close(fil)
    return output
end

test_def1 = ["      logical boun_flag,cload_flag,"
             "     &  nodeprint_flag"]

test_def2 = ["      character*1 typeboun(*),inpc(*)"
             "      character*3 output"]

test_def3 = ["      integer kon(*),nodempc(3,*),"
             "     &  nodeforc(2,*),iaxial,"
             "     &  istartset(*)"]

facts("Testing findalldefinitions(file_lines)") do
    @fact findalldefinitions(test_def1) -->
        Dict{Any,Any}("logical" => Any["boun_flag","cload_flag","nodeprint_flag"])
    @fact findalldefinitions(test_def2) -->
        Dict{Any,Any}("character" => Any["typeboun","inpc","output"])
    @fact findalldefinitions(test_def3) -->
        Dict{Any,Any}("integer" => Any["kon","nodempc","nodeforc","iaxial","istartset"])
end

function ptrtypes(arg,dictoftypes)
    for key in keys(dictoftypes)
        if arg in dictoftypes[key]
            if key == "real"
                return "Ptr{Float64}"
            elseif key == "integer"
                return "Ptr{Int64}"
            elseif key == "logical"
                return "Ptr{Bool}"
            elseif key == "character"
                return "Ptr{ASCIIString}"
            end
        end
    end
end

function writeccall(args,dictoftypes)
    out = @sprintf "ccall((:%s_, ../deps/usr/lib/libcalculix.so), Int64,\n" "calinput"
    final = length(args)
    for (num,arg) in enumerate(args)
        if num == final
            out = out * @sprintf "%s),\n       " ptrtypes(arg,dictoftypes)
            break
        end
        if num == 1
            out = out * "       ("
        elseif (num % 5) == 0
            out = out * "\n        "
        else
            out = out * @sprintf "%s," ptrtypes(arg,dictoftypes)
        end
    end
    for (num,arg) in enumerate(args)
        if num == final
            out = out * @sprintf "%s)\n" arg
            break
        end
        if (num % 4) == 0
            out = out * "\n       "
        end
        out = out * @sprintf "%s," arg
    end
    println(out)
end
fil = open("../deps/src/CalculiX-cmake/src/fortran/calinput.f")
lines = readlines(fil)
close(fil)
arglist = find_subroutine_args(lines)
argdefs = findalldefinitions(lines)
writeccall(arglist,argdefs)
