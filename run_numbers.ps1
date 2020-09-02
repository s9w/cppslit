# $vcvars_dir = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\VC\Auxiliary\Build\vcvars64.bat"
$vcvars_dir = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Preview\VC\Auxiliary\Build\vcvars64.bat"

$repetitions = 30
$boost_dir = "F:\cpp-lit-libs\boost_1_74_0"
$date_dir = "F:\cpp-lit-libs\date-master\include"
$tracy_dir = "F:\cpp-lit-libs\tracy-0.7.1"
$spdlog_dir = "F:\cpp-lit-libs\spdlog-1.8.0\include"
$fmt_dir = "F:\cpp-lit-libs\fmt-7.0.3\include"
$doctest_dir = "F:\cpp-lit-libs\doctest-2.4.0"
$imgui_dir = "F:\cpp-lit-libs\imgui-1.78"
$nljson_dir = "F:\cpp-lit-libs\json-3.9.1\include"
$use_windows = $true
$use_std_modules = $true
$use_std_headers = $true

"use_std_headers: {0}, use_std_modules: {1}, use_windows: {2}, boost: {3}, date: {4}" -f $use_std_headers, $use_std_modules, $use_windows, (Test-Path variable:boost_dir), (Test-Path variable:date_dir)

function Invoke-CmdScript {
  param(
    [String] $scriptName
  )
  $cmdLine = """$scriptName"" $args & set"
  & $Env:SystemRoot\system32\cmd.exe /c $cmdLine |
  select-string '^([^=]*)=(.*)$' | foreach-object {
    $varName = $_.Matches[0].Groups[1].Value
    $varValue = $_.Matches[0].Groups[2].Value
    set-item Env:$varName $varValue
  }
}
if((-Not (Test-Path env:cpp_lit_invoked_vcvars)) -And (-Not $env:cpp_lit_invoked_vcvars)){
   Write-Output "running invoke"
   Invoke-CmdScript $vcvars_dir
   # prevent running that script more than once per session. It's slow and there's an issue with multiple invokations
   $env:cpp_lit_invoked_vcvars = $true
}


$include_dirs = @()
if(Test-Path variable:boost_dir){
   $include_dirs += $boost_dir
}
if(Test-Path variable:date_dir){
   $include_dirs += $date_dir
}
if(Test-Path variable:tracy_dir){
   $include_dirs += $tracy_dir
}
if(Test-Path variable:spdlog_dir){
   $include_dirs += $spdlog_dir
}
if(Test-Path variable:fmt_dir){
   $include_dirs += $fmt_dir
}
if(Test-Path variable:doctest_dir){
   $include_dirs += $doctest_dir
}
if(Test-Path variable:imgui_dir){
   $include_dirs += $imgui_dir
}
if(Test-Path variable:nljson_dir){
   $include_dirs += $nljson_dir
}
$include_statement = ""
Foreach($include_dir in $include_dirs){
   $include_statement += "/I""" + $include_dir + """ "
}
Write-Output "include statement: " $include_statement

function run_meas($category, $inc, $repeats, $config)
{
   For ($i=0; $i -lt $repeats; $i++){
      $cl_command = "CL " + $include_statement + "/O2 /MD /D " + "i_" + $inc + " /std:c++latest /experimental:module /EHsc /nologo build_project/main.cpp /link /MACHINE:X64"
      Measure-Command {
         if($config -eq "Release"){
            Invoke-Expression $cl_command
         }
         else{
            Invoke-Expression $cl_command
         }
         } | Out-File -FilePath "measurements\$category-$inc-$config.txt" -Append -Encoding utf8
   }
}

$std_headers = "algorithm","any","array","atomic","bitset","cassert","cctype","cerrno","cfenv","cfloat","charconv","chrono","cinttypes","climits","clocale","cmath","compare","complex","concepts","condition_variable","csetjmp","csignal","cstdarg","cstddef","cstdint","cstdio","cstdlib","cstring","ctime","cuchar","cwchar","cwctype","deque","exception","execution","filesystem","forward_list","fstream","functional","future","initializer_list","iomanip","ios","iosfwd","iostream","istream","iterator","limits","list","locale","map","memory_resource","memory","mutex","new","numeric","optional","ostream","queue","random","ranges","ratio","regex","scoped_allocator","set","shared_mutex","sstream","stack","stdexcept","streambuf","string_view","string","system_error","thread","tuple","type_traits","typeindex","typeinfo","unordered_map","unordered_set","utility","valarray","variant","vector","version","bit","coroutine","numbers","span"
$std_modules = "std_regex","std_filesystem","std_memory","std_threading","std_core"
$boost_headers = "boost_variant2","boost_optional","boost_uuid","boost_asio","boost_atomic","boost_beast","boost_outcome","boost_any","boost_hana"

$misc_headers = @("null")
if($use_windows){
   $misc_headers += "windows","windows_mal"
}
if(Test-Path variable:date_dir){
   $misc_headers += "date_date","date_tz"
}
if(Test-Path variable:tracy_dir){
   $misc_headers += "tracy"
}
if(Test-Path variable:spdlog_dir){
   $misc_headers += "spdlog"
}
if(Test-Path variable:fmt_dir){
   $misc_headers += "fmt"
}
if(Test-Path variable:doctest_dir){
   $misc_headers += "doctest"
}
if(Test-Path variable:imgui_dir){
   $misc_headers += "imgui"
}
if(Test-Path variable:nljson_dir){
   $misc_headers += "nl_json_fwd","nl_json"
}

if(Test-Path measurements){
   Remove-Item measurements -Recurse
}
new-item -Name measurements -ItemType directory -Force | out-null # create measurements dir if it doesn't exist

run_meas "std" "warmup" $repetitions "Release"
Foreach($header in $misc_headers){
   run_meas "misc" $header $repetitions "Release"
   run_meas "misc" $header $repetitions "Debug"
}
if(Test-Path variable:boost_dir){
   Foreach($header in $boost_headers){
      run_meas "boost" $header $repetitions "Release"
      run_meas "boost" $header $repetitions "Debug"
   }
}
if($use_std_modules){
   Foreach($header in $std_modules){
      run_meas "std_modules" $header $repetitions "Release"
      run_meas "std_modules" $header $repetitions "Debug"
   }
}
if($use_std_headers){
   Foreach($header in $std_headers){
      run_meas "std" $header $repetitions "Release"
      run_meas "std" $header $repetitions "Debug"
   }
}
