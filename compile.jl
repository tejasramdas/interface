]activate .
using PackageCompiler

create_sysimage(["GLMakie"];sysimage_path="Interface.so",precompile_execution_file="patch_interface.jl")

