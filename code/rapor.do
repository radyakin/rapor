clear all
/*
rapor , ///
  outfolder("C:/temp/4") ///
  outfile("out.html") ///
  exportfile("c:/Users/serjr/Downloads/HOUSEHOLD_1_STATA_All (3).zip") ///
  scheme("stcolor") imagewidth(800) minstr(4) strlimit(10)
*/
rapor , ///
  outfolder("C:/temp/5") ///
  outfile("out.html") ///
  exportfile("c:/Users/serjr/Downloads/dairy_inbound_adoption_2_STATA_All.zip") ///
  scheme("stcolor") imagewidth(800) minstr(4) strlimit(10)  

rapor, des

/*
upftp , folder("c:/Temp/5/") fileslist(`files') ///
        cfile("c:/Data/Git/rapor/rapor_test.ftp")
  */
// END OF FILE
