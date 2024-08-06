python:

import json
from sfi import Macro

foundfields=""

def foundq(s):
  global foundfields
  print(" "+s['VariableName']+":"+s['QuestionText'])
  foundfields=foundfields+" "+s['VariableName']

def traverse(node):
  if (node['Children']!=None):
	for child in node['Children']:
	  if (child['\$type']=="SingleQuestion"):
		if (('LinkedToRosterId' not in child) and ('LinkedToQuestionId' not in child)):
		  foundq(child)
	  if (child['\$type']=="Group"):
		if (child['IsRoster']!=True): ## // not going inside the rosters for now
		  traverse(child)

def proc(fname):
  global foundfields
  foundfields=""
  with open(fname, 'r') as f:
	Q = json.load(f)  

  SECTIONS=Q['Children']
  for oneSection in SECTIONS:
	# // print("======"+oneSection['Title']+"======")
	traverse(oneSection)
  Macro.setLocal("foundfields",foundfields)
  return(foundfields)
end

program define rapor
    version 18.0
	
	quietly which fre // requires: FRE

	local outfolder="C:\temp\4\"
	local outfile="out.html"

	local questions="region result material_walls material_roof"
	python: print(proc("c:/Temp/4/Questionnaire/content/document.json"))
	display `"`foundfields'"'
	local questions=`"`foundfields'"'

	use "c:/Temp/4/Household.dta"
	replace region=.
	local fontname="Arial"

	file open fh using "`outfolder'\`outfile'", write text replace
	file write fh "<HTML>" _n

	foreach q in `questions' {
		file write fh `"<H2><FONT face="`fontname'">`q': `:variable label `q'' </FONT></H2>"' _n
		
		// check if there are any observations in `q'!
		
		quietly count if !missing(`q')
		
		if (r(N)==0) {
			file write fh `"<FONT face="`fontname'">No observations</FONT>"'
		}
		else {
			set graphics off
			graph pie if (!missing(`q')), over(`q') plabel(_all percent , format(%8.1f)) // Option scale() is not permitted here, see: https://www.stata.com/statalist/archive/2008-05/msg00195.html
			graph display, scale(1.00)
			graph export "`outfolder'\_`q'.png", as(png) width(1200) replace
			// graph doesn't show both percent and label - see: https://www.statalist.org/forums/forum/general-stata-discussion/general/1129-pie-chart-with-labels-and-percantage-together-on-slice
			
			quietly fre `q' if (!missing(`q'))
			matrix F= r(valid)
			local labels `"`r(lab_valid)' "'
			display `"`labels'"'
			local n=r(N)

			file write fh `"<CENTER><IMG src="_`q'.png" width=600></CENTER>"' _n
			file write fh `"<CENTER><TABLE border="1" cellpadding="6" cellspacing="0" width="800px" style="border-collapse:collapse;">"' _n
			file write fh `"<TH bgcolor="orange"><FONT face="`fontname'">Value</FONT></TH><TH bgcolor="orange" width=100><FONT face="`fontname'">Percent</FONT></TH><TH bgcolor="orange" width=100><FONT face="`fontname'">Responses</FONT></TH>"' _n
			local r=`:rowsof F'
			forval i=1/`r' {
				local p=string(F[`i',1]/`n'*100.0,"%25.1f")+"%"
				//local ll `"`:word `i' of `labels''"' // works unexpectedly with unbalanced quotes
				gettoken ll labels : labels
				display `"`ll'"'
				local ppp=strpos(`"`ll'"', " ")
				local ll=substr(`"`ll'"',`ppp'+1,.)
				file write fh `"<TR><TD><FONT face="`fontname'">`ll'</FONT></TD><TD align="right"><FONT face="`fontname'">`p'</FONT></TD><TD align="right"><FONT face="`fontname'">`=F[`i',1]'</FONT></TD></TR>"' _n
			}
			file write fh `"<TR><TD colspan=3 align="right"><FONT face="`fontname'"><B>Totals:`n'</B></FONT></TD></TR>"' _n
			file write fh "</TABLE></CENTER>" _n
		}
	}

	file close fh

end

// END OF FILE
