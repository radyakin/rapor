python:

import json
from sfi import Macro
from dataclasses import dataclass

@dataclass
class qinfo:
  fname:str = ""
  title:str = ""
  text:str = ""
  single:str = ""
  multi:str = ""
  all:str = ""
  
  def reset(self):
    self.fname=""
    self.title=""
    self.text=""
    self.single=""
    self.multi=""
    self.all=""

Q=qinfo()

def foundq(s):
  global Q
  Q.all=Q.all + " " + s['VariableName']
  print(" "+s['VariableName']+":"+s['QuestionText'])

def foundq_single(s):
  global Q
  Q.single=Q.single+" "+s['VariableName']
  foundq(s)

def foundq_text(s):
  global Q
  Q.text=Q.text+" "+s['VariableName']
  foundq(s)

def traverse(node):
  if (node['Children']!=None):
	for child in node['Children']:
	  if (child['\$type']=="SingleQuestion"):
		if (('LinkedToRosterId' not in child) and ('LinkedToQuestionId' not in child)):
		  foundq_single(child)
	  if (child['\$type']=="TextQuestion"):
	    foundq_text(child)
	  if (child['\$type']=="Group"):
		if (child['IsRoster']!=True): ## // not going inside the rosters for now
		  traverse(child)

def proc(fname):
  global Q
  Q.reset()
 
  with open(fname, 'r') as f:
    QUEST = json.load(f)  

  Q.fname=QUEST['VariableName']
  Q.title=QUEST['Title']

  SECTIONS=QUEST['Children']
  for oneSection in SECTIONS:
    # // print("======"+oneSection['Title']+"======")
    traverse(oneSection)
  Macro.setLocal("foundfields_single",Q.single)
  Macro.setLocal("foundfields_text",Q.text)
  Macro.setLocal("foundfields_multi",Q.multi)
  Macro.setLocal("foundfields_all",Q.all)
  Macro.setLocal("mainfile",Q.fname)
  print(Q)
  return(Q.all)
end

program define rapor
    
	version 18.0
	quietly which fre // requires: FRE

	syntax , ///
	  outfolder(string) ///  // destination folder where output will be saved, may not be empty!
	  [outfile(string)] ///  // name of the output file (default is index.html)
	  exportfile(string)
	
	if (`"`outfile'"'=="") local outfile="index.html"
	
	if !fileexists(`"`exportfile'"') {
		display as error `"File `exportfile' does not exist."
		error 601
	}
	
	local pwd `c(pwd)'
	
	cd `"`outfolder'"'
	mkdir "_TEMP"
	cd "_TEMP"
	unzipfile `"`exportfile'"' // unpack all contents of the export file (data)
	mkdir "_CONTENT"
	cd "_CONTENT"
	unzipfile `"../Questionnaire/content.zip"' // unpack questionnaire document
	local jsonfile=`"`outfolder'/_TEMP/_CONTENT/document.json"'
	
	cd `"`pwd'"'

	python: print(proc("`jsonfile'"))
	display `"`foundfields_all'"'
	local questions=`"`foundfields_all'"'

	use "`outfolder'/_TEMP/`mainfile'.dta"
	// no longer need temporary content after the data is loaded
	shell rmdir "`outfolder'/_TEMP" /s /q   
	
	replace material_walls=4 in 9  // CLEAN UP THIS
	replace material_walls_other="Test" in 9
	
	local fontname="Arial"

	file open fh using "`outfolder'/`outfile'", write text replace
	file write fh "<HTML><BODY>" _n

	foreach q in `questions' {
		file write fh `"<H2><FONT face="`fontname'">`q': `:variable label `q'' </FONT></H2>"' _n
		
		// check if there are any observations in `q'!
		if (strpos(" `foundfields_text' ", " `q' ")>0) {
			// Process text field
			count if (!missing(`q') & (`q'!="##N/A##"))
			if (r(N)==0) {
				file write fh `"<FONT face="`fontname'">No observations</FONT>"'
			}
			else {
				file write fh `"<TABLE border="1" cellpadding="6" cellspacing="0" width="800px" style="border-collapse:collapse;">"'
				file write fh `"<B>ResponseID</B><B>Response</B>"'
				forval i=1/`=_N' {
					if (!missing(`q'[`i']) & (`q'[`i']!="##N/A##")) {
						file write fh `"<FONT face="Courier New">`=interview__key[`i']'</FONT>&nbsp;&nbsp;&nbsp;:&nbsp;&nbsp;&nbsp;<I> `=`q'[`i']'</I><BR>"' _n
					}
				}
				file write fh `"</TABLE>"'
			}
		}
		if (strpos(" `foundfields_single' ", " `q' ")>0) {
		
			quietly count if !missing(`q')
			
			if (r(N)==0) {
				file write fh `"<FONT face="`fontname'">No observations</FONT>"'
			}
			else {
				set graphics off
				graph pie if (!missing(`q')), ///
				  over(`q') plabel(_all percent , format(%8.1f)) ///
				  scheme("stgcolor_mv") // Option scale() is not permitted here, see: https://www.stata.com/statalist/archive/2008-05/msg00195.html
				graph display, scale(1.00) // workaround for scale
				graph export "`outfolder'\_`q'.png", as(png) width(1200) replace
				// graph doesn't show both percent and label - see: https://www.statalist.org/forums/forum/general-stata-discussion/general/1129-pie-chart-with-labels-and-percantage-together-on-slice

				quietly fre `q' if (!missing(`q'))
				matrix F= r(valid)
				local labels `"`r(lab_valid)' "'
				local n=r(N)

				file write fh `"<CENTER><A href="_`q'.png"><IMG src="_`q'.png" width=600></A></CENTER>"' _n
				file write fh `"<CENTER><TABLE border="1" cellpadding="6" cellspacing="0" width="800px" style="border-collapse:collapse;">"' _n
				file write fh `"<TH bgcolor="orange"><FONT face="`fontname'">Value</FONT></TH><TH bgcolor="orange" width=100><FONT face="`fontname'">Percent</FONT></TH><TH bgcolor="orange" width=100><FONT face="`fontname'">Responses</FONT></TH>"' _n
				local r=`:rowsof F'
				forval i=1/`r' {
					local p=string(F[`i',1]/`n'*100.0,"%25.1f")+"%"
					//local ll `"`:word `i' of `labels''"' // works unexpectedly with unbalanced quotes
					gettoken ll labels : labels
					local ppp=strpos(`"`ll'"', " ")
					local ll=substr(`"`ll'"',`ppp'+1,.)
					file write fh `"<TR><TD><FONT face="`fontname'">`ll'</FONT></TD><TD align="right"><FONT face="`fontname'">`p'</FONT></TD><TD align="right"><FONT face="`fontname'">`=F[`i',1]'</FONT></TD></TR>"' _n
				}
				file write fh `"<TR><TD colspan=3 align="right"><FONT face="`fontname'"><B>Totals:`n'</B></FONT></TD></TR>"' _n
				file write fh "</TABLE></CENTER>" _n
			}
		}
	}
	file write fh "</BODY></HTML>"
	file close fh

end

// END OF FILE
