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

  def savetolocals(self, root):
    Macro.setLocal(root+"_single", self.single)
    Macro.setLocal(root+"_text", self.text)
    Macro.setLocal(root+"_multi", self.multi)
    Macro.setLocal(root+"_all", self.all)
    Macro.setLocal(root+"_mainfile", self.fname)
    Macro.setLocal(root+"_title", self.title)

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
  Q.savetolocals("Q")
  # // return(Q.all)
end

program define rapor
    
	version 18.0
	quietly which fre // requires: FRE

	syntax , ///
	  outfolder(string)      ///  // destination folder where output will be saved, may not be empty!
	  [outfile(string)]      ///  // short name of the output file (default is index.html)
	  exportfile(string)     /// // full name of the export data file
	  [scheme(string)]       /// // Scheme name (optional, default is currently set scheme.)
	  [imagewidth(int 1200)] /// // Image width (optional, default is 1200)
	  [strlimit(int 99)]     /// // Limit on number of open text answers included (default=99).
	  [minstr(int 0)]        /// // Min length of open text answer to be considered for showing (default=0)
	
	if (`"`outfile'"'=="") local outfile="index.html"
	
	if !fileexists(`"`exportfile'"') {
		display as error `"File `exportfile' does not exist."
		error 601
	}
	
	local pwd `c(pwd)'
	
	quietly {
		cd `"`outfolder'"'
		mkdir "_TEMP"
		cd "_TEMP"
		unzipfile `"`exportfile'"' // unpack all contents of the export file (data)
		mkdir "_CONTENT"
		cd "_CONTENT"
		unzipfile `"../Questionnaire/content.zip"' // unpack questionnaire document
		local jsonfile=`"`outfolder'/_TEMP/_CONTENT/document.json"'
		
		cd `"`pwd'"'
	}

	python: proc("`jsonfile'")
	//display `"`Q_all'"'
	local questions=`"`Q_all'"'
	
	// Read production date
	tempname fr
	file open `fr' using "`outfolder'/_TEMP/export__readme.txt", read text
	  file read `fr' oneline
	file close `fr'
	local proddate=substr(`"`oneline'"',strpos(`"`oneline'"',", ")+2,.)
	
	use "`outfolder'/_TEMP/`Q_mainfile'.dta"
	// no longer need temporary content after the data is loaded
	shell rmdir "`outfolder'/_TEMP" /s /q   
	/*
	replace material_walls=4 in 9  // FOR TESTING PURPOSES ONLY
	replace material_walls_other="Test" in 9 */
	
	local fontname="Arial"
	local fontnamefx="Courier New"
	local wtable=800
	local wimage=600
	local wcolumn=120

	file open fh using "`outfolder'/`outfile'", write text replace
	file write fh "<HTML>" _n
	file write fh "<STYLE>" _n
	file write fh "@media print {" _n
	file write fh "    .pagebreak { page-break-before: always; }" _n
	file write fh "}"
	file write fh "</STYLE>" _n
	
	file write fh "<BODY>" _n
	
	// HEADER
	
	file write fh `"<a href="https://mysurvey.solutions/" target="_blank" class="logo"><img src="data:image/svg&#x2B;xml;base64,PHN2ZyB3aWR0aD0iOTAiIGhlaWdodD0iNDUiIHZpZXdCb3g9IjAgMCA5MCA0NSIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZmlsbC1ydWxlPSJldmVub2RkIiBjbGlwLXJ1bGU9ImV2ZW5vZGQiIGQ9Ik05LjcgMjguNEM5LjggMjguMiA5LjkgMjcuOSAxMCAyNy43QzEwLjYgMjYuMiAxMC43IDI2LjEgMTAuNyAyNC4yVjE2LjhIOC43VjI0LjJDOC43IDI2IDguNyAyNi4xIDkuMyAyNy42QzkuNSAyNy45IDkuNiAyOC4yIDkuNyAyOC40Wk0xMC42IDMxLjNDMTEgMzAuMyAxMS40IDI5LjQgMTEuOCAyOC40QzEyLjYgMjYuNSAxMi42IDI2LjQgMTIuNiAyNC4yVjE1LjhDMTIuNiAxNS4yIDEyLjQgMTQuOCAxMS42IDE0LjhIOC43VjEyLjhIMTQuNFYyNC4xQzE0LjQgMjYuOCAxNC4zIDI2LjkgMTMuNSAyOS4xQzEyLjIgMzIuMiAxMC45IDM1LjMgOS43IDM4LjVDOC40IDM1LjQgNy4xIDMyLjIgNS45IDI5LjFDNS4xIDI3LjEgNSAyNi45IDUgMjQuM1YxNi44SDYuOVYyNC4yQzYuOSAyNi40IDYuOSAyNi41IDcuNyAyOC40TDguOSAzMS4zQzkuMyAzMi41IDEwLjEgMzIuNSAxMC42IDMxLjNaTTQgMTQuOUg2LjlWMTJDNi45IDExLjMgNy4yIDExIDcuOSAxMUgxNS41QzE2LjMgMTEgMTYuNSAxMS4zIDE2LjUgMTJWMjQuMkMxNi41IDI3LjIgMTYuNCAyNy40IDE1LjQgMjkuOUMxMy44IDMzLjcgMTIuMyAzNy42IDEwLjcgNDEuNEMxMC4xIDQyLjkgOS41IDQyLjkgOC45IDQxLjRDNy4zIDM3LjUgNS44IDMzLjcgNC4yIDI5LjhDMy4xIDI3LjYgMyAyNy4zIDMgMjQuM1YxNS44QzMgMTUuMyAzLjEgMTQuOSA0IDE0LjlaIiBmaWxsPSIjNDU0NTQ1Ii8&#x2B;CjxwYXRoIGZpbGwtcnVsZT0iZXZlbm9kZCIgY2xpcC1ydWxlPSJldmVub2RkIiBkPSJNNC45IDEyLjRDNC45IDEzIDQuNSAxMyA0IDEzQzMuNSAxMyAzIDEzIDMgMTIuNFY4QzMgNy40IDMuMiA3IDQgN0gxNC41VjQuOUgzLjZDMyA0LjkgMyA0LjUgMyA0QzMgMy41IDMgMyAzLjYgM0gxNS40QzE2LjIgMyAxNi40IDMuMiAxNi40IDRWOEMxNi40IDguNiAxNi4yIDkgMTUuNCA5SDQuOVYxMi40WiIgZmlsbD0iIzQ1NDU0NSIvPgo8cGF0aCBkPSJNMjcuNyAyNC44QzI3LjggMjUuNiAyOC42IDI2IDI5LjcgMjZDMzAuNyAyNiAzMS40IDI1LjUgMzEuNCAyNC44QzMxLjQgMjQuMiAzMSAyMy44IDI5LjggMjMuNkwyOC44IDIzLjRDMjcgMjMgMjYuMSAyMi4xIDI2LjEgMjAuOEMyNi4xIDE5LjEgMjcuNiAxOCAyOS42IDE4QzMxLjggMTggMzMuMSAxOS4xIDMzLjIgMjAuOEgzMS40QzMxLjMgMjAgMzAuNiAxOS41IDI5LjcgMTkuNUMyOC43IDE5LjUgMjguMSAxOS45IDI4LjEgMjAuNkMyOC4xIDIxLjIgMjguNSAyMS41IDI5LjYgMjEuN0wzMC42IDIxLjlDMzIuNiAyMi4zIDMzLjQgMjMuMSAzMy40IDI0LjVDMzMuNCAyNi4zIDMyIDI3LjQgMjkuNyAyNy40QzI3LjUgMjcuNCAyNiAyNi4zIDI2IDI0LjZIMjcuN1YyNC44WiIgZmlsbD0iIzQ1NDU0NSIvPgo8cGF0aCBkPSJNMzQuMSAyMy45QzM0LjEgMjEuNyAzNS40IDIwLjMgMzcuNSAyMC4zQzM5LjYgMjAuMyA0MC45IDIxLjYgNDAuOSAyMy45QzQwLjkgMjYuMiAzOS42IDI3LjUgMzcuNSAyNy41QzM1LjQgMjcuNSAzNC4xIDI2LjIgMzQuMSAyMy45Wk0zOSAyNEMzOSAyMi42IDM4LjQgMjEuOCAzNy41IDIxLjhDMzYuNiAyMS44IDM2IDIyLjYgMzYgMjRDMzYgMjUuNCAzNi42IDI2LjIgMzcuNSAyNi4yQzM4LjQgMjYuMSAzOSAyNS4zIDM5IDI0WiIgZmlsbD0iIzQ1NDU0NSIvPgo8cGF0aCBkPSJNNDEuOSAxOC4xSDQzLjhWMjcuM0g0MS45VjE4LjFaIiBmaWxsPSIjNDU0NTQ1Ii8&#x2B;CjxwYXRoIGQ9Ik01MS41IDI3LjRINDkuN1YyNi4yQzQ5LjQgMjcuMSA0OC43IDI3LjYgNDcuNiAyNy42QzQ2LjEgMjcuNiA0NS4xIDI2LjYgNDUuMSAyNVYyMC42SDQ3VjI0LjZDNDcgMjUuNSA0Ny41IDI2IDQ4LjMgMjZDNDkuMSAyNiA0OS43IDI1LjQgNDkuNyAyNC41VjIwLjZINTEuNlYyNy40SDUxLjVaIiBmaWxsPSIjNDU0NTQ1Ii8&#x2B;CjxwYXRoIGQ9Ik01NSAxOC45VjIwLjVINTYuM1YyMS45SDU1VjI1LjJDNTUgMjUuNyA1NS4zIDI2IDU1LjggMjZDNTYgMjYgNTYuMSAyNiA1Ni4zIDI2VjI3LjRDNTYuMSAyNy40IDU1LjggMjcuNSA1NS40IDI3LjVDNTMuOCAyNy41IDUzLjIgMjcgNTMuMiAyNS42VjIySDUyLjJWMjAuNkg1My4yVjE5SDU1VjE4LjlaIiBmaWxsPSIjNDU0NTQ1Ii8&#x2B;CjxwYXRoIGQ9Ik01Ny4zIDE4LjZDNTcuMyAxOC4xIDU3LjcgMTcuNiA1OC4zIDE3LjZDNTguOSAxNy42IDU5LjMgMTggNTkuMyAxOC42QzU5LjMgMTkuMSA1OC45IDE5LjYgNTguMyAxOS42QzU3LjcgMTkuNiA1Ny4zIDE5LjIgNTcuMyAxOC42Wk01Ny4zIDIwLjVINTkuMlYyNy40SDU3LjNWMjAuNVoiIGZpbGw9IiM0NTQ1NDUiLz4KPHBhdGggZD0iTTYwLjIgMjMuOUM2MC4yIDIxLjcgNjEuNSAyMC4zIDYzLjYgMjAuM0M2NS43IDIwLjMgNjcgMjEuNiA2NyAyMy45QzY3IDI2LjIgNjUuNyAyNy41IDYzLjYgMjcuNUM2MS41IDI3LjUgNjAuMiAyNi4yIDYwLjIgMjMuOVpNNjUuMSAyNEM2NS4xIDIyLjYgNjQuNSAyMS44IDYzLjYgMjEuOEM2Mi43IDIxLjggNjIuMSAyMi42IDYyLjEgMjRDNjIuMSAyNS40IDYyLjcgMjYuMiA2My42IDI2LjJDNjQuNSAyNi4xIDY1LjEgMjUuMyA2NS4xIDI0WiIgZmlsbD0iIzQ1NDU0NSIvPgo8cGF0aCBkPSJNNjggMjAuNUg2OS44VjIxLjdDNzAuMiAyMC44IDcwLjkgMjAuMyA3MS45IDIwLjNDNzMuNCAyMC4zIDc0LjMgMjEuMyA3NC4zIDIyLjlWMjcuM0g3Mi40VjIzLjNDNzIuNCAyMi40IDcyIDIxLjkgNzEuMSAyMS45QzcwLjIgMjEuOSA2OS43IDIyLjUgNjkuNyAyMy40VjI3LjNINjhWMjAuNVoiIGZpbGw9IiM0NTQ1NDUiLz4KPHBhdGggZD0iTTc4LjMgMjAuNEM4MC4xIDIwLjQgODEuMiAyMS4zIDgxLjIgMjIuNkg3OS41Qzc5LjQgMjIgNzkgMjEuNyA3OC4zIDIxLjdDNzcuNyAyMS43IDc3LjIgMjIgNzcuMiAyMi40Qzc3LjIgMjIuOCA3Ny41IDIzIDc4LjEgMjMuMUw3OS4zIDIzLjRDODAuNyAyMy43IDgxLjMgMjQuMyA4MS4zIDI1LjNDODEuMyAyNi43IDgwLjEgMjcuNSA3OC4zIDI3LjVDNzYuNCAyNy41IDc1LjMgMjYuNiA3NS4yIDI1LjNINzdDNzcuMSAyNS45IDc3LjUgMjYuMiA3OC4zIDI2LjJDNzkgMjYuMiA3OS40IDI1LjkgNzkuNCAyNS41Qzc5LjQgMjUuMSA3OS4yIDI0LjkgNzguNSAyNC44TDc3LjMgMjQuNkM3NiAyNC4zIDc1LjMgMjMuNyA3NS4zIDIyLjZDNzUuNCAyMS4yIDc2LjYgMjAuNCA3OC4zIDIwLjRaIiBmaWxsPSIjNDU0NTQ1Ii8&#x2B;CjxwYXRoIGQ9Ik0yNy45IDEwLjhDMjggMTEuNiAyOC44IDEyIDI5LjggMTJDMzAuOCAxMiAzMS41IDExLjUgMzEuNSAxMC44QzMxLjUgMTAuMiAzMS4xIDkuOCAyOS45IDkuNkwyOC45IDkuNEMyNy4xIDkgMjYuMiA4LjEgMjYuMiA2LjhDMjYuMiA1LjEgMjcuNyA0IDI5LjcgNEMzMS45IDQgMzMuMiA1LjEgMzMuMyA2LjhIMzEuNUMzMS40IDYgMzAuNyA1LjUgMjkuOCA1LjVDMjguOCA1LjUgMjguMiA1LjkgMjguMiA2LjZDMjguMiA3LjIgMjguNiA3LjUgMjkuNyA3LjdMMzAuNyA3LjlDMzIuNyA4LjMgMzMuNSA5LjEgMzMuNSAxMC41QzMzLjUgMTIuMyAzMi4xIDEzLjQgMjkuOCAxMy40QzI3LjYgMTMuNCAyNi4xIDEyLjMgMjYuMSAxMC42SDI3LjlWMTAuOFoiIGZpbGw9IiM0NTQ1NDUiLz4KPHBhdGggZD0iTTQxIDEzLjRIMzkuMlYxMi4yQzM4LjkgMTMuMSAzOC4yIDEzLjYgMzcuMSAxMy42QzM1LjYgMTMuNiAzNC42IDEyLjYgMzQuNiAxMVY2LjVIMzYuNVYxMC41QzM2LjUgMTEuNCAzNyAxMS45IDM3LjggMTEuOUMzOC42IDExLjkgMzkuMiAxMS4zIDM5LjIgMTAuNFY2LjVINDFWMTMuNFoiIGZpbGw9IiM0NTQ1NDUiLz4KPHBhdGggZD0iTTQyLjIgNi41SDQ0VjcuN0M0NC4yIDYuOCA0NC44IDYuNCA0NS42IDYuNEM0NS44IDYuNCA0NiA2LjQgNDYuMSA2LjVWOC4xQzQ2LjEgOC4xIDQ1LjggOCA0NS42IDhDNDQuNyA4IDQ0LjEgOC42IDQ0LjEgOS41VjEzLjNINDIuMlY2LjVaIiBmaWxsPSIjNDU0NTQ1Ii8&#x2B;CjxwYXRoIGQ9Ik01MS4yIDEzLjRINDkuMUw0Ni43IDYuNUg0OC43TDUwLjEgMTEuN0w1MS41IDYuNUg1My41TDUxLjIgMTMuNFoiIGZpbGw9IiM0NTQ1NDUiLz4KPHBhdGggZD0iTTYwLjIgMTEuM0M2MCAxMi42IDU4LjggMTMuNSA1Ny4xIDEzLjVDNTUgMTMuNSA1My43IDEyLjEgNTMuNyA5LjlDNTMuNyA3LjcgNTUgNi4zIDU3IDYuM0M1OSA2LjMgNjAuMyA3LjcgNjAuMyA5LjdWMTAuM0g1NS42VjEwLjRDNTUuNiAxMS40IDU2LjIgMTIuMSA1Ny4yIDEyLjFDNTcuOSAxMi4xIDU4LjQgMTEuOCA1OC42IDExLjJINjAuMlYxMS4zWk01NS42IDkuM0g1OC41QzU4LjUgOC40IDU3LjkgNy44IDU3LjEgNy44QzU2LjIgNy44IDU1LjYgOC40IDU1LjYgOS4zWiIgZmlsbD0iIzQ1NDU0NSIvPgo8cGF0aCBkPSJNNjEuMiAxNS45VjE0LjVDNjEuMyAxNC41IDYxLjYgMTQuNSA2MS43IDE0LjVDNjIuNCAxNC41IDYyLjcgMTQuMyA2Mi44IDEzLjdMNjIuOSAxMy40TDYwLjUgNi41SDYyLjZMNjQgMTEuOUw2NS41IDYuNUg2Ny41TDY1LjEgMTMuNUM2NC41IDE1LjMgNjMuNyAxNS45IDYxLjkgMTUuOUM2MS44IDE2IDYxLjIgMTYgNjEuMiAxNS45WiIgZmlsbD0iIzQ1NDU0NSIvPgo8L3N2Zz4K" alt="Survey Solutions" width=120 /></a>"' _n
	
	file write fh `"<TABLE><TR><TD width=100><TD align=center>"' _n
	file write fh `"<BR><BR>"' _n
	file write fh `"<H1>Data Report</H1>"' _n
	file write fh `"<H1>for</H1>"' _n
	file write fh `"<H1><FONT color="Navy"><I>`Q_title'</I></FONT></H1>"'_n
	file write fh `"Data as of: `proddate'"' _n
	file write fh `"<BR><BR><BR><BR><BR><BR><BR><BR><BR>"' _n
	file write fh `"</TD></TR></TABLE>"' _n

	foreach q in `questions' {
		file write fh `"<div class="pagebreak"> </div><H2><FONT face="`fontname'">`q': `:variable label `q'' </FONT></H2>"' _n
		
		// check if there are any observations in `q'!
		if (strpos(" `Q_text' ", " `q' ")>0) {
			// Process text field
			quietly count if (!missing(`q') & (`q'!="##N/A##") & (strtrim(`q')!="") & (strlen(strtrim(`q'))>`minstr'))
			if (r(N)==0) {
				file write fh `"<FONT face="`fontname'">No observations</FONT>"'
			}
			else {
				file write fh `"<CENTER><TABLE border="0" cellpadding="6" cellspacing="0" width="`wtable'px" style="border-collapse:collapse;">"'
				file write fh `"<TR><TH width=`wcolumn' align=left>ResponseID</TH><TH align=left>Response</TH></TR>"'
				
				local written=0
				forval i=1/`=_N' {
					if (!missing(`q'[`i']) & (`q'[`i']!="##N/A##")& (strtrim(`q'[`i'])!="") & (strlen(strtrim(`q'[`i']))>`minstr')) {
						file write fh `"<TR><TD><FONT face="`fontnamefx'" size=3>`=interview__key[`i']'</FONT></TD><TD><I> `=`q'[`i']'</I></TD></TR>"' _n

						local written=`written'+1
						if (`written'>=`strlimit') continue, break

					}
				}
				file write fh `"</TABLE></CENTER>"'
			}
		}
		if (strpos(" `Q_single' ", " `q' ")>0) {
		
			quietly count if !missing(`q')
			
			if (r(N)==0) {
				file write fh `"<FONT face="`fontname'">No observations</FONT>"'
			}
			else {
				local grmode=`"`c(graphics)'"'
				set graphics off
				graph pie if (!missing(`q')), ///
				  over(`q') plabel(_all percent , format(%8.1f)) ///
				  scheme("`scheme'") // Option scale() is not permitted here, see: https://www.stata.com/statalist/archive/2008-05/msg00195.html
				graph display, scale(1.00) // workaround for scale
				graph export "`outfolder'/_`q'.png", as(png) width(`imagewidth') replace
				// graph doesn't show both percent and label - see: https://www.statalist.org/forums/forum/general-stata-discussion/general/1129-pie-chart-with-labels-and-percantage-together-on-slice
				set graphics `grmode'

				quietly fre `q' if (!missing(`q'))
				matrix F= r(valid)
				local labels `"`r(lab_valid)' "'
				local n=r(N)

				file write fh `"<CENTER><A href="_`q'.png"><IMG src="_`q'.png" width=`wimage'></A></CENTER>"' _n
				file write fh `"<CENTER><TABLE border="1" cellpadding="6" cellspacing="0" width="`wtable'px" style="border-collapse:collapse;">"' _n
				file write fh `"<TH bgcolor="orange"><FONT face="`fontname'">Value</FONT></TH><TH bgcolor="orange" width=`wcolumn'><FONT face="`fontname'">Percent</FONT></TH><TH bgcolor="orange" width=`wcolumn'><FONT face="`fontname'">Responses</FONT></TH>"' _n
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
