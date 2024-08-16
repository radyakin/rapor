clear all

rapor , ///
  outfolder("C:/temp/4") ///
  outfile("out.html") ///
  exportfile("c:/Users/serjr/Downloads/HOUSEHOLD_1_STATA_All (3).zip") ///
  scheme("stcolor") imagewidth(800) minstr(4) strlimit(10)

return list  
local files `"`r(filenames)'"'
di `"`files'"'
local n `: word count `files''

display as text "The report consists of the following {result:`n'} files:"
local i=1
foreach f in `files' {
	display as text `"`i'. {result:`f'}"'
	local i=`i'+1
}
  
// END OF FILE
