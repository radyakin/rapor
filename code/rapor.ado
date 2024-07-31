program define rapor
    version 18.0
	
	quietly which fre // requires: FRE

	local outfolder="C:\temp\4\"
	local outfile="out.html"

	use "Household.dta"
	local questions="region result material_walls material_roof"

	local fontname="Arial"

	file open fh using "`outfolder'\`outfile'", write text replace
	file write fh "<HTML>" _n

	foreach q in `questions' {
		set graphics off
		graph pie , over(`q') plabel(_all percent) // Option scale() is not permitted here, see: https://www.stata.com/statalist/archive/2008-05/msg00195.html
		graph display, scale(0.5)
		graph export "`outfolder'\_`q'.png", as(png) width(800) replace
		// graph doesn't show both percent and label - see: https://www.statalist.org/forums/forum/general-stata-discussion/general/1129-pie-chart-with-labels-and-percantage-together-on-slice
		
		quietly fre `q'
		matrix F= r(valid)
		local labels `"`r(lab_valid)'"'
		local n=r(N)

		file write fh `"<H2><FONT face="`fontname'">`q': `:variable label `q'' </FONT></H2>"' _n
		file write fh `"<CENTER><IMG src="_`q'.png"></CENTER>"'
		file write fh "<TABLE border=1 width=800>" _n
		file write fh `"<TH bgcolor="orange"><FONT face="`fontname'">Value</FONT></TH><TH bgcolor="orange" width=100><FONT face="`fontname'">Percent</FONT></TH><TH bgcolor="orange" width=100><FONT face="`fontname'">Responses</FONT></TH>"' _n
		local r=`:rowsof F'
		forval i=1/`r' {
			local p=string(F[`i',1]/`n'*100.0,"%25.1f")+"%"
			local ll `"`:word `i' of `labels''"'
			local ppp=strpos(`"`ll'"', " ")
			local ll=substr(`"`ll'"',`ppp'+1,.)
			file write fh `"<TR><TD><FONT face="`fontname'">`ll'</FONT></TD><TD align="right"><FONT face="`fontname'">`p'</FONT></TD><TD align="right"><FONT face="`fontname'">`=F[`i',1]'</FONT></TD></TR>"' _n
		}
		file write fh `"<TR><TD colspan=3 align="right"><FONT face="`fontname'"><B>Totals:`n'</B></FONT></TD></TR>"' _n
		file write fh "</TABLE>" _n
		
	}

	file close fh

end

// END OF FILE
