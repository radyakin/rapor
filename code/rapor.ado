python:

import json
from sfi import Macro, Data
from dataclasses import dataclass
import ftplib

def setstyle():
    Macro.setLocal("fontname","Arial")
    Macro.setLocal("fontnamefx","Courier New")
    Macro.setLocal("wtable","800")
    Macro.setLocal("wimage","600")
    Macro.setLocal("wcolumn","120")
    Macro.setLocal("nfmt","%19.2fc")
    Macro.setLocal("pfmt","%25.1f")
    Macro.setLocal("hcolor","#FFD700")
    Macro.setLocal("bcolor","#005BBB")

def setLanguage(lng):
    # // Current frame should contain translations
    for i in range(Data.getObsTotal()):
      left=Data.get("value",i)[0][0]
      right=Data.get("lng_"+lng,i)[0][0]
      Macro.setLocal(left,right)

@dataclass
class qinfo:
  fname:str = ""
  title:str = ""
  text:str = ""
  numeric:str = ""
  single:str = ""
  multi:str = ""
  all:str = ""
  cats={}
  titles={}
  levels={}
  files={}
  
  def reset(self):
    self.fname=""
    self.title=""
    self.text=""
    self.numeric=""
    self.single=""
    self.multi=""
    self.all=""
    self.cats={}
    self.titles={}
    self.levels={}
    self.files={}

  def savetolocals(self, root):
    Macro.setLocal(root+"_single", self.single)
    Macro.setLocal(root+"_text", self.text)
    Macro.setLocal(root+"_numeric", self.numeric)
    Macro.setLocal(root+"_multi", self.multi)
    Macro.setLocal(root+"_all", self.all)
    Macro.setLocal(root+"_mainfile", self.fname)
    Macro.setLocal(root+"_title", self.title)
    
    k=self.cats.keys()
    for key in k:
      Macro.setLocal(root+"_c__"+key, self.cats[key])

  def getQuestionTitle(self, q):
    return(self.titles[q])

  def getQuestionLevel(self, q):
    return(self.levels[q])

  def getFrameForQuestion(self, q):
    p=self.levels[q]
    Z=p.split('/')
    zl=len(Z)
    fil=Z[zl-1]
    fra=self.files[fil]
    return(fra)

  def alllevs(self):
    t={}
    for l in self.levels:
      p=self.levels[l]
      if p not in t:
        Z=p.split('/')
        zl=len(Z)
        t[p]=Z[zl-1]
    i=1
    for q in t:
      f=t[q]
      print(str(i)+" "+f)
      self.files[f]=i # // this is the frame number
      i=i+1

  def getAllFiles(self):
    s=""
    for f in self.files:
      s=s+" "+f
    return(s.strip())

Q=qinfo()

def foundq(s, level):
  global Q
  vn=s['VariableName']
  qt=s['QuestionText']
  Q.all=Q.all + " " + vn
  Q.titles[vn]=qt
  print(" "+level+" {" + vn + "}:" + qt)
  Q.levels[vn]=level

def foundq_single(s, level):
  global Q
  Q.single=Q.single+" "+s['VariableName']
  foundq(s, level)

def foundq_multi(s, level):
  global Q
  vn=s['VariableName']
  Q.multi=Q.multi+" "+vn
  Q.cats[vn]=""
  for a in s['Answers']:
    Q.cats[vn]=Q.cats[vn] + " \"" + a['AnswerText']+"\""
  foundq(s, level)
  
def foundq_text(s, level):
  global Q
  Q.text=Q.text+" "+s['VariableName']
  foundq(s, level)
  
def foundq_numeric(s, level):
  global Q
  Q.numeric=Q.numeric+" "+s['VariableName']
  foundq(s, level)
  
def traverse(node, level):
  if (node['Children']!=None):
	for child in node['Children']:
	  if (child['\$type']=="SingleQuestion"):
		if (('LinkedToRosterId' not in child) and ('LinkedToQuestionId' not in child)):
		  foundq_single(child, level)
	  if (child['\$type']=="MultyOptionsQuestion"):
	    if ('CategoriesId' not in child):
	      foundq_multi(child, level)
	  if (child['\$type']=="TextQuestion"):
	    foundq_text(child, level)
	  if (child['\$type']=="NumericQuestion"):
	    foundq_numeric(child, level)
	  if (child['\$type']=="Group"):
		if (child['IsRoster']!=True): ## // not going inside the rosters for now
		  traverse(child, level)
		else:
		  traverse(child, level+"/"+child['VariableName'])

def proc(fname):
  global Q
  Q.reset()
 
  with open(fname, 'r', encoding='utf8') as f:
    QUEST = json.load(f)  

  Q.fname=QUEST['VariableName']
  Q.title=QUEST['Title']

  SECTIONS=QUEST['Children']
  for oneSection in SECTIONS:
    # // print("======"+oneSection['Title']+"======")
    traverse(oneSection,Q.fname)
  Q.savetolocals("Q")
  Q.alllevs()

end


program define graph_mselect, rclass
    version 18.0
    syntax , vname(string) lbls(string) [title(string)] /// // this is expected to be read from the JSON of the questionnaire
    [format(string)] /// 
    [percent] 
  
    if (`"`format'"'=="") local format="%6.1f"
	quietly ds `vname'__*
	local vnames=r(varlist)
	
	local n : word count `vnames'
	
	tempname M
	matrix `M'=J(`n',2,.)

	if ("`percent'"!="") {
		local scalor=100
		local range1="0(10)100"
		local range2="0(5)100"	
	}
	else {
		local scalor=1
		local range1="0(.1)1"
		local range2="0(.05)1"
	}

	frame create GDATA
	frame GDATA: generate cat=.
	frame GDATA: generate strL lbl=""
	frame GDATA: generate mean=.

	tempname valuelabel
	local nn=.

	forval i=1/`n' {
		
		local ii=`n'+1-`i'
		local vn : word `i' of `vnames'
		summarize `vn', meanonly
		local nn=r(N)
		
		if (`nn'==0) {
			// No observations:
			matrix `M'[`i',1]=0
			matrix `M'[`i',2]=0
		}
		else {
			quietly count if `vn'>0 & !missing(`vn')
			matrix `M'[`i',2]=r(N)
			local mm=r(N)/`nn'*`scalor'
			matrix `M'[`i',1]=`mm'
		}
		
		frame post GDATA (`ii') (`"`: word `i' of `lbls''"') (`mm') 
		local `valuelabel' `ii' `"`: word `i' of `lbls''"' ``valuelabel''
		frame GDATA: label define `valuelabel' `ii' `"`: word `i' of `lbls''"', modify
	}

	frame GDATA {
		label values cat `valuelabel'
		generate meanstr=string(mean, "`format'")+cond(`scalor'==100,"%","")

		graph twoway ///
		  (scatter mean cat, ///
		  scale(0.75) recast(bar) horizontal ///
		  ylabel(`range1') ylabel(``valuelabel'') ///
		  xtitle(`"`=cond(`scalor'==100,"percent","")'"') ///
		  ytitle("") ///
		  title(`title')) ///
		  (scatter cat mean, ///
		  msymbol(none) mlabel(meanstr)), ///
		  ///
		  xlabel(`range1') xmtick(`range2') legend(off)
	}
	
	frame drop GDATA
	return matrix M=`M'
	return scalar N=`n'
	return scalar NN=`nn'

end

program define rapor
	version 18.0
	
	capture syntax , DEScribe
	if !_rc {
		_rapor_describe
		exit
	}
	
	_rapor `0'
	
end

program define _rapor_describe
    version 18.0
	
	local files `"`r(filenames)'"'
	// di `"`files'"'
	local n `: word count `files''

	display as text "The report consists of the following {result:`n'} files:"
	local i=1
	foreach f in `files' {
		display as text `"`i'. {result:`f'}"'
		local i=`i'+1
	}
end

program define _numstat, rclass
  version 18.0
  syntax varname
  
  quietly summarize `varlist'   // perhaps exclude special values??
  local vn=r(N)
  local vmean=r(mean)
  local vmin=r(min)
  local vmax=r(max)
  local vsd=r(sd)

  quietly centile `varlist', c(10 25 50 75 90)
  local vc10=r(c_1)
  local vc25=r(c_2)
  local vc50=r(c_3)
  local vc75=r(c_4)
  local vc90=r(c_5)
  
  return scalar N=`vn'
  return scalar mean=`vmean'
  return scalar min=`vmin'
  return scalar max=`vmax'
  return scalar sd=`vsd'
  
  return scalar c10=`vc10'
  return scalar c25=`vc25'
  return scalar c50=`vc50'
  return scalar c75=`vc75'
  return scalar c90=`vc90'

end

program define _loadAllData
    version 18.0
    syntax , datafolder(string)
    local i=1
    python : Macro.setLocal("allfiles",Q.getAllFiles())
    display `"`allfiles'"'
    foreach f in `allfiles' {
		local fname="data_`i'"
		display as text `"Loading {result:"`f'.dta"} to frame {result:`fname'}..."' _continue
		frame create `fname'
		frame `fname': use `"`datafolder'/`f'.dta"'
		display as text " ok"
		local i=`i'+1
	}
	frame dir
end

program define _getProdDate, rclass
    version 18.0
	syntax , file(string)

	// Read production date
	tempname fr
	file open `fr' using `"`file'"', read text
	  file read `fr' oneline
	file close `fr'
	local proddate = substr(`"`oneline'"', strpos(`"`oneline'"', ", ") + 2, .)
	local proddate = string(date("`proddate'","MDY"),"%tdCCYY-NN-DD")
	return local proddate = `"`proddate'"'
end

program define _qlist, rclass
    version 18.0
	
	syntax , [whitelist(string)] [blacklist(string)]
	
	// Narrow down the questions list
	// local questions=`"`Q_all'"'
	python: Macro.setLocal("questions", Q.all)
	// Apply whitelist and blacklist options if specified:
	if (`"`whitelist'"'!="") local questions `"`: list questions & whitelist'"'
	if (`"`blacklist'"'!="") local questions `"`: list questions - blacklist'"'
	python: Q.all="`questions'" // needed for TOC
	return local questions = `"`questions'"'
end

program define loadlng
    version 18.0
    clear
    capture frame create rapor_lng
    frame rapor_lng {
      findfile "rapor_translation.csv"
      import delimited using "`r(fn)'", clear varnames(1)
      python: setLanguage("en")
    }
    // https://www.deepl.com/en/translator
    // https://translate.google.com/
end

program define _rapor, rclass
    
	version 18.0
		
	quietly which fre // requires: FRE

	syntax , ///
	  outfolder(string)      ///  // Destination folder where output will be saved, may not be empty!
	  [outfile(string)]      ///  // Short name of the output file (default is index.html)
	  exportfile(string)     ///  // Full name of the export data file
	  [scheme(string)]       ///  // Scheme name (optional, default is currently set scheme.)
	  [imagewidth(int 1200)] ///  // Image width (optional, default is 1200)
	  [strlimit(int 99)]     ///  // Limit on number of open text answers included (default=99).
	  [minstr(int 0)]        ///  // Min length of open text answer to be considered for showing (default=0)
	  [whitelist(string)]    ///  // Variables' whitelist - only these variables will be analyzed (optional)
	  [blacklist(string)]    ///  // Variables' blacklist - these variables will not be included into the report (optional)
	  [language(string)]     ///  // 2-letter language code for string literals in the report (optional, English [en] will be used by default)
	
	if (`"`language'"'=="") local language="en"
	
	loadlng
	frame rapor_lng : python: setLanguage("`language'")
	
	local result=""
	
	if (`"`outfile'"'=="") local outfile="index.html"
	
	if !fileexists(`"`exportfile'"') {
		display as error `"File `exportfile' does not exist."
		error 601
	}
	
	
	// -------------------------------------------------------------------------
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
	_loadAllData, datafolder("`outfolder'/_TEMP")

	_getProdDate, file("`outfolder'/_TEMP/export__readme.txt")
	local proddate `r(proddate)'
	
	use "`outfolder'/_TEMP/`Q_mainfile'.dta"
	// no longer need temporary content after the data is loaded
	shell rmdir "`outfolder'/_TEMP" /s /q   
	// This deletes the temporary folder with any files
	// -------------------------------------------------------------------------

	_qlist, whitelist(`"`whitelist'"') blacklist(`"`blacklist'"')
	local questions `r(questions)'

	python: setstyle()
	
	local result `"`result' "`outfile'""'
	file open fh using "`outfolder'/`outfile'", write text replace

	_writeFileHeader fh
	_writeTitlePage fh, title(`"`Q_title'"') proddate(`"`proddate'"') language("`language'")

	foreach q in `questions' {
		display as result "`q'"
		python: Macro.setLocal("qframe", str(Q.getFrameForQuestion("`q'")))
		frame change data_`qframe'
		
		_writeQuestionHeader fh, question(`"`q'"')
		
		if (strpos(" `Q_numeric' ", " `q' ")>0) {
			
			_numstat `q'
			if (r(N)>0) {
			
				file write fh "<B>`txt_descriptive_statistics'</B><BR><BR>" _n
				local cstyle=`" align="center""'
				file write fh `"<CENTER><TABLE border="1" cellpadding="6" cellspacing="0" width="`wtable'px" style="border-collapse:collapse;">"' _n
				file write fh `"<TR><TH `cstyle' bgcolor="`hcolor'"><FONT face="`fontname'">`txt_statistic'</FONT></TH>"' _n
				file write fh `"<TD `cstyle'>`txt_n'</TD>"'
				file write fh `"<TD `cstyle'>`txt_mean'</TD>"'
				file write fh `"<TD `cstyle'>`txt_minimum'</TD>"'
				file write fh `"<TD `cstyle'>`txt_maximum'</TD>"'
				file write fh `"<TD `cstyle'>`txt_standard_deviation'</TD></TR>"' _n
				
				file write fh `"<TR><TH width=16% bgcolor="`hcolor'"><FONT face="`fontname'">`txt_value'</FONT></TH>"' _n
				file write fh `"<TD width=16% `cstyle'><TT>`r(N)'</TT></TD>"'
				file write fh `"<TD width=17% `cstyle'><TT>`=string(`r(mean)',"`nfmt'")'</TT></TD>"'
				file write fh `"<TD width=17% `cstyle'><TT>`=string(`r(min)',"`nfmt'")'</TT></TD>"'
				file write fh `"<TD width=17% `cstyle'><TT>`=string(`r(max)',"`nfmt'")'</TT></TD>"'
				file write fh `"<TD width=17% `cstyle'><TT>`=string(`r(sd)',"`nfmt'")'</TT></TD></TR>"' _n
				file write fh `"</TABLE></CENTER>"' _n

				file write fh `"<BR><B>`txt_percentiles'</B><BR><BR>"' _n
				file write fh `"<CENTER><TABLE border="1" cellpadding="6" cellspacing="0" width="`wtable'px" style="border-collapse:collapse;">"' _n
				file write fh `"  <TR><TH `cstyle' bgcolor="`hcolor'"><FONT face="`fontname'">`txt_percentile'</FONT></TH><TD `cstyle'>10</TD><TD `cstyle'>25</TD><TD `cstyle'>50</TD><TD `cstyle'>75</TD><TD `cstyle'>90</TD></TR>"' _n
				file write fh `"  <TR><TH width=16% `cstyle' bgcolor="`hcolor'"><FONT face="`fontname'">`txt_value'</FONT></TH>"'
				file write fh `"  <TD width=16% `cstyle'><TT>`=string(`r(c10)',"`nfmt'")'</TT></TD>"' _n
				file write fh `"  <TD width=17% `cstyle'><TT>`=string(`r(c25)',"`nfmt'")'</TT></TD>"' _n
				file write fh `"  <TD width=17% `cstyle'><TT>`=string(`r(c50)',"`nfmt'")'</TT></TD>"' _n
				file write fh `"  <TD width=17% `cstyle'><TT>`=string(`r(c75)',"`nfmt'")'</TT></TD>"' _n
				file write fh `"  <TD width=17% `cstyle'><TT>`=string(`r(c90)',"`nfmt'")'</TT></TD>"' _n
				file write fh `"  </TR>"' _n
				file write fh `"</TABLE></CENTER>"' _n
			}
			else {
				file write fh `"<FONT face="`fontname'">`txt_no_observations'</FONT>"'
			}
		}
		if (strpos(" `Q_text' ", " `q' ")>0) {
			// Process text field
			quietly count if (!missing(`q') & (`q'!="##N/A##") & (strtrim(`q')!="") & (strlen(strtrim(`q'))>`minstr'))
			if (r(N)==0) {
				file write fh `"<FONT face="`fontname'">`txt_no_observations'</FONT>"'
			}
			else {
				file write fh `"<CENTER><TABLE border="0" cellpadding="6" cellspacing="0" width="`wtable'px" style="border-collapse:collapse;">"'
				file write fh `"<TR><TH width=`wcolumn' align=left>`txt_observation_id'</TH><TH align=left>`txt_response'</TH></TR>"'
				
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
				quietly graph export "`outfolder'/_`q'.png", as(png) width(`imagewidth') replace
				// graph doesn't show both percent and label - see: https://www.statalist.org/forums/forum/general-stata-discussion/general/1129-pie-chart-with-labels-and-percantage-together-on-slice
				set graphics `grmode'
				local result `"`result' "_`q'.png""'

				quietly fre `q' if (!missing(`q'))
				matrix F= r(valid)
				local labels `"`r(lab_valid)' "'
				local n=r(N)

				file write fh `"<CENTER><A href="_`q'.png"><IMG src="_`q'.png" width=`wimage'></A></CENTER>"' _n
				file write fh `"<CENTER><TABLE border="1" cellpadding="6" cellspacing="0" width="`wtable'px" style="border-collapse:collapse;">"' _n
				file write fh `"<TH bgcolor="`hcolor'"><FONT face="`fontname'">`txt_value'</FONT></TH><TH colspan=2 bgcolor="`hcolor'"><FONT face="`fontname'">`txt_percent'</FONT></TH><TH bgcolor="`hcolor'" width=`wcolumn'><FONT face="`fontname'">`txt_responses'</FONT></TH>"' _n
				local r=`:rowsof F'
				forval i=1/`r' {
					local p=string(F[`i',1]/`n'*100.0,"`pfmt'")+"%"
					//local ll `"`:word `i' of `labels''"' // works unexpectedly with unbalanced quotes
					gettoken ll labels : labels
					local ppp=strpos(`"`ll'"', " ")
					local ll=substr(`"`ll'"',`ppp'+1,.)
					file write fh `"<TR><TD><FONT face="`fontname'">`ll'</FONT></TD><TD  width=`wcolumn' align="right"><FONT face="`fontname'">`p'</FONT></TD><TD width=`wcolumn'><div class="bar" style="width: `p';"></TD><TD align="right"><FONT face="`fontname'">`=F[`i',1]'</FONT></TD></TR>"' _n
				}
				file write fh `"<TR><TD colspan=4 align="right"><FONT face="`fontname'"><B>`txt_total':`n'</B></FONT></TD></TR>"' _n
				file write fh "</TABLE></CENTER>" _n
			}
		}
		if (strpos(" `Q_multi' ", " `q' ")>0) {

			quietly ds `q'__*
			local vnames=r(varlist)
			//quietly count if !missing(`q')
			
			local noobs=1
			foreach v in `vnames' {
				quietly count if !missing(`v')
				if (r(N)>0) {
					local noobs=0
					continue, break
				}
			}
			
			if (`noobs'==1) {
				file write fh `"<FONT face="`fontname'">`txt_no_observations'</FONT>"'
			}
			else {
				local labels `"`Q_c__`q''"'
				local grmode=`"`c(graphics)'"'
				set graphics off
					graph_mselect, vname(`q') ///
						title(`""') ///
						lbls(`"`Q_c__`q''"') ///
						format("`pfmt'") ///
						percent 
					matrix F=r(M)
					local n=r(NN)
					graph display, scale(1.00) // workaround for scale
					quietly graph export "`outfolder'/_`q'.png", as(png) width(`imagewidth') replace
				set graphics `grmode'
				local result `"`result' "_`q'.png""'

				file write fh `"<CENTER><A href="_`q'.png"><IMG src="_`q'.png" width=`wimage'></A></CENTER>"' _n

				file write fh `"<CENTER><TABLE border="1" cellpadding="6" cellspacing="0" width="`wtable'px" style="border-collapse:collapse;">"' _n
				file write fh `"<TH bgcolor="`hcolor'"><FONT face="`fontname'">`txt_value'</FONT></TH><TH bgcolor="`hcolor'" width=`wcolumn'><FONT face="`fontname'">`txt_percent'</FONT></TH><TH bgcolor="`hcolor'" width=`wcolumn'><FONT face="`fontname'">`txt_responses'</FONT></TH>"' _n
				local r=`:rowsof F'
				forval i=1/`r' {
					local p=string(F[`i',1],"`pfmt'")+"%"
					gettoken ll labels : labels
					file write fh `"<TR><TD><FONT face="`fontname'">`ll'</FONT></TD><TD align="right"><FONT face="`fontname'">`p'</FONT></TD><TD align="right"><FONT face="`fontname'">`=F[`i',2]'</FONT></TD></TR>"' _n
				}
				file write fh `"<TR><TD colspan=3 align="right"><FONT face="`fontname'"><B>`txt_total_responses':`n'</B></FONT></TD></TR>"' _n
				file write fh "</TABLE></CENTER>" _n
			}
		}
		
	}
	file write fh "</BODY></HTML>"
	file close fh
	
	return local filenames `"`result'"'
	
	display `"{browse "`outfolder'/`outfile'":Open report in browser}"'

end

program define _writeFileHeader
    version 18.0
    syntax anything
	
	python: setstyle()
	
	file write `anything' "<!DOCTYPE html"
	file write `anything' "<HTML>" _n
	file write `anything' `"<HEAD><META http-equiv="Content-Type" content="text/html; charset=utf-8"></HEAD>"' _n
	file write `anything' "<STYLE>" _n
	file write `anything' ".bar {" _n
	file write `anything' "height:20px;" _n
	file write `anything' "background-color: `bcolor';" _n
	file write `anything' "}" _n
	file write `anything' "@media print {" _n
	file write `anything' "    .pagebreak { page-break-before: always; }" _n
	file write `anything' "}" _n
	file write `anything' "</STYLE>" _n
end

program define _writeTitlePage
    version 18.0
	syntax anything, title(string) proddate(string) language(string)
	
	frame rapor_lng : python: setLanguage("`language'")
	
	// HEADER
	_writeLogo `anything'
	
	file write `anything' `"<TABLE><TR><TD width=100><TD align=center>"' _n
	file write `anything' `"<BR><BR>"' _n
	file write `anything' `"<H1>`txt_data_report'</H1>"' _n
	//file write `anything' `"<H1>for</H1>"' _n
	file write `anything' `"<H1><FONT color="Navy"><I>`title'</I></FONT></H1>"'_n
	file write `anything' `"`txt_data_as_of': `proddate'<BR><BR>"' _n
	file write `anything' `"`txt_built_with' <A href="https://github.com/radyakin/rapor">rapor</A>"' _n
	file write `anything' `"<BR><BR><BR><BR><BR><BR><BR><BR><BR>"' _n
	file write `anything' `"</TD></TR></TABLE>"' _n
	
	_writeToc `anything', language("`language'")
end


program define _writeLogo

    version 18.0
	syntax anything
	
    	file write `anything' `"<a href="https://mysurvey.solutions/" target="_blank" class="logo"><img src="data:image/svg&#x2B;xml;base64,PHN2ZyB3aWR0aD0iOTAiIGhlaWdodD0iNDUiIHZpZXdCb3g9IjAgMCA5MCA0NSIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZmlsbC1ydWxlPSJldmVub2RkIiBjbGlwLXJ1bGU9ImV2ZW5vZGQiIGQ9Ik05LjcgMjguNEM5LjggMjguMiA5LjkgMjcuOSAxMCAyNy43QzEwLjYgMjYuMiAxMC43IDI2LjEgMTAuNyAyNC4yVjE2LjhIOC43VjI0LjJDOC43IDI2IDguNyAyNi4xIDkuMyAyNy42QzkuNSAyNy45IDkuNiAyOC4yIDkuNyAyOC40Wk0xMC42IDMxLjNDMTEgMzAuMyAxMS40IDI5LjQgMTEuOCAyOC40QzEyLjYgMjYuNSAxMi42IDI2LjQgMTIuNiAyNC4yVjE1LjhDMTIuNiAxNS4yIDEyLjQgMTQuOCAxMS42IDE0LjhIOC43VjEyLjhIMTQuNFYyNC4xQzE0LjQgMjYuOCAxNC4zIDI2LjkgMTMuNSAyOS4xQzEyLjIgMzIuMiAxMC45IDM1LjMgOS43IDM4LjVDOC40IDM1LjQgNy4xIDMyLjIgNS45IDI5LjFDNS4xIDI3LjEgNSAyNi45IDUgMjQuM1YxNi44SDYuOVYyNC4yQzYuOSAyNi40IDYuOSAyNi41IDcuNyAyOC40TDguOSAzMS4zQzkuMyAzMi41IDEwLjEgMzIuNSAxMC42IDMxLjNaTTQgMTQuOUg2LjlWMTJDNi45IDExLjMgNy4yIDExIDcuOSAxMUgxNS41QzE2LjMgMTEgMTYuNSAxMS4zIDE2LjUgMTJWMjQuMkMxNi41IDI3LjIgMTYuNCAyNy40IDE1LjQgMjkuOUMxMy44IDMzLjcgMTIuMyAzNy42IDEwLjcgNDEuNEMxMC4xIDQyLjkgOS41IDQyLjkgOC45IDQxLjRDNy4zIDM3LjUgNS44IDMzLjcgNC4yIDI5LjhDMy4xIDI3LjYgMyAyNy4zIDMgMjQuM1YxNS44QzMgMTUuMyAzLjEgMTQuOSA0IDE0LjlaIiBmaWxsPSIjNDU0NTQ1Ii8&#x2B;CjxwYXRoIGZpbGwtcnVsZT0iZXZlbm9kZCIgY2xpcC1ydWxlPSJldmVub2RkIiBkPSJNNC45IDEyLjRDNC45IDEzIDQuNSAxMyA0IDEzQzMuNSAxMyAzIDEzIDMgMTIuNFY4QzMgNy40IDMuMiA3IDQgN0gxNC41VjQuOUgzLjZDMyA0LjkgMyA0LjUgMyA0QzMgMy41IDMgMyAzLjYgM0gxNS40QzE2LjIgMyAxNi40IDMuMiAxNi40IDRWOEMxNi40IDguNiAxNi4yIDkgMTUuNCA5SDQuOVYxMi40WiIgZmlsbD0iIzQ1NDU0NSIvPgo8cGF0aCBkPSJNMjcuNyAyNC44QzI3LjggMjUuNiAyOC42IDI2IDI5LjcgMjZDMzAuNyAyNiAzMS40IDI1LjUgMzEuNCAyNC44QzMxLjQgMjQuMiAzMSAyMy44IDI5LjggMjMuNkwyOC44IDIzLjRDMjcgMjMgMjYuMSAyMi4xIDI2LjEgMjAuOEMyNi4xIDE5LjEgMjcuNiAxOCAyOS42IDE4QzMxLjggMTggMzMuMSAxOS4xIDMzLjIgMjAuOEgzMS40QzMxLjMgMjAgMzAuNiAxOS41IDI5LjcgMTkuNUMyOC43IDE5LjUgMjguMSAxOS45IDI4LjEgMjAuNkMyOC4xIDIxLjIgMjguNSAyMS41IDI5LjYgMjEuN0wzMC42IDIxLjlDMzIuNiAyMi4zIDMzLjQgMjMuMSAzMy40IDI0LjVDMzMuNCAyNi4zIDMyIDI3LjQgMjkuNyAyNy40QzI3LjUgMjcuNCAyNiAyNi4zIDI2IDI0LjZIMjcuN1YyNC44WiIgZmlsbD0iIzQ1NDU0NSIvPgo8cGF0aCBkPSJNMzQuMSAyMy45QzM0LjEgMjEuNyAzNS40IDIwLjMgMzcuNSAyMC4zQzM5LjYgMjAuMyA0MC45IDIxLjYgNDAuOSAyMy45QzQwLjkgMjYuMiAzOS42IDI3LjUgMzcuNSAyNy41QzM1LjQgMjcuNSAzNC4xIDI2LjIgMzQuMSAyMy45Wk0zOSAyNEMzOSAyMi42IDM4LjQgMjEuOCAzNy41IDIxLjhDMzYuNiAyMS44IDM2IDIyLjYgMzYgMjRDMzYgMjUuNCAzNi42IDI2LjIgMzcuNSAyNi4yQzM4LjQgMjYuMSAzOSAyNS4zIDM5IDI0WiIgZmlsbD0iIzQ1NDU0NSIvPgo8cGF0aCBkPSJNNDEuOSAxOC4xSDQzLjhWMjcuM0g0MS45VjE4LjFaIiBmaWxsPSIjNDU0NTQ1Ii8&#x2B;CjxwYXRoIGQ9Ik01MS41IDI3LjRINDkuN1YyNi4yQzQ5LjQgMjcuMSA0OC43IDI3LjYgNDcuNiAyNy42QzQ2LjEgMjcuNiA0NS4xIDI2LjYgNDUuMSAyNVYyMC42SDQ3VjI0LjZDNDcgMjUuNSA0Ny41IDI2IDQ4LjMgMjZDNDkuMSAyNiA0OS43IDI1LjQgNDkuNyAyNC41VjIwLjZINTEuNlYyNy40SDUxLjVaIiBmaWxsPSIjNDU0NTQ1Ii8&#x2B;CjxwYXRoIGQ9Ik01NSAxOC45VjIwLjVINTYuM1YyMS45SDU1VjI1LjJDNTUgMjUuNyA1NS4zIDI2IDU1LjggMjZDNTYgMjYgNTYuMSAyNiA1Ni4zIDI2VjI3LjRDNTYuMSAyNy40IDU1LjggMjcuNSA1NS40IDI3LjVDNTMuOCAyNy41IDUzLjIgMjcgNTMuMiAyNS42VjIySDUyLjJWMjAuNkg1My4yVjE5SDU1VjE4LjlaIiBmaWxsPSIjNDU0NTQ1Ii8&#x2B;CjxwYXRoIGQ9Ik01Ny4zIDE4LjZDNTcuMyAxOC4xIDU3LjcgMTcuNiA1OC4zIDE3LjZDNTguOSAxNy42IDU5LjMgMTggNTkuMyAxOC42QzU5LjMgMTkuMSA1OC45IDE5LjYgNTguMyAxOS42QzU3LjcgMTkuNiA1Ny4zIDE5LjIgNTcuMyAxOC42Wk01Ny4zIDIwLjVINTkuMlYyNy40SDU3LjNWMjAuNVoiIGZpbGw9IiM0NTQ1NDUiLz4KPHBhdGggZD0iTTYwLjIgMjMuOUM2MC4yIDIxLjcgNjEuNSAyMC4zIDYzLjYgMjAuM0M2NS43IDIwLjMgNjcgMjEuNiA2NyAyMy45QzY3IDI2LjIgNjUuNyAyNy41IDYzLjYgMjcuNUM2MS41IDI3LjUgNjAuMiAyNi4yIDYwLjIgMjMuOVpNNjUuMSAyNEM2NS4xIDIyLjYgNjQuNSAyMS44IDYzLjYgMjEuOEM2Mi43IDIxLjggNjIuMSAyMi42IDYyLjEgMjRDNjIuMSAyNS40IDYyLjcgMjYuMiA2My42IDI2LjJDNjQuNSAyNi4xIDY1LjEgMjUuMyA2NS4xIDI0WiIgZmlsbD0iIzQ1NDU0NSIvPgo8cGF0aCBkPSJNNjggMjAuNUg2OS44VjIxLjdDNzAuMiAyMC44IDcwLjkgMjAuMyA3MS45IDIwLjNDNzMuNCAyMC4zIDc0LjMgMjEuMyA3NC4zIDIyLjlWMjcuM0g3Mi40VjIzLjNDNzIuNCAyMi40IDcyIDIxLjkgNzEuMSAyMS45QzcwLjIgMjEuOSA2OS43IDIyLjUgNjkuNyAyMy40VjI3LjNINjhWMjAuNVoiIGZpbGw9IiM0NTQ1NDUiLz4KPHBhdGggZD0iTTc4LjMgMjAuNEM4MC4xIDIwLjQgODEuMiAyMS4zIDgxLjIgMjIuNkg3OS41Qzc5LjQgMjIgNzkgMjEuNyA3OC4zIDIxLjdDNzcuNyAyMS43IDc3LjIgMjIgNzcuMiAyMi40Qzc3LjIgMjIuOCA3Ny41IDIzIDc4LjEgMjMuMUw3OS4zIDIzLjRDODAuNyAyMy43IDgxLjMgMjQuMyA4MS4zIDI1LjNDODEuMyAyNi43IDgwLjEgMjcuNSA3OC4zIDI3LjVDNzYuNCAyNy41IDc1LjMgMjYuNiA3NS4yIDI1LjNINzdDNzcuMSAyNS45IDc3LjUgMjYuMiA3OC4zIDI2LjJDNzkgMjYuMiA3OS40IDI1LjkgNzkuNCAyNS41Qzc5LjQgMjUuMSA3OS4yIDI0LjkgNzguNSAyNC44TDc3LjMgMjQuNkM3NiAyNC4zIDc1LjMgMjMuNyA3NS4zIDIyLjZDNzUuNCAyMS4yIDc2LjYgMjAuNCA3OC4zIDIwLjRaIiBmaWxsPSIjNDU0NTQ1Ii8&#x2B;CjxwYXRoIGQ9Ik0yNy45IDEwLjhDMjggMTEuNiAyOC44IDEyIDI5LjggMTJDMzAuOCAxMiAzMS41IDExLjUgMzEuNSAxMC44QzMxLjUgMTAuMiAzMS4xIDkuOCAyOS45IDkuNkwyOC45IDkuNEMyNy4xIDkgMjYuMiA4LjEgMjYuMiA2LjhDMjYuMiA1LjEgMjcuNyA0IDI5LjcgNEMzMS45IDQgMzMuMiA1LjEgMzMuMyA2LjhIMzEuNUMzMS40IDYgMzAuNyA1LjUgMjkuOCA1LjVDMjguOCA1LjUgMjguMiA1LjkgMjguMiA2LjZDMjguMiA3LjIgMjguNiA3LjUgMjkuNyA3LjdMMzAuNyA3LjlDMzIuNyA4LjMgMzMuNSA5LjEgMzMuNSAxMC41QzMzLjUgMTIuMyAzMi4xIDEzLjQgMjkuOCAxMy40QzI3LjYgMTMuNCAyNi4xIDEyLjMgMjYuMSAxMC42SDI3LjlWMTAuOFoiIGZpbGw9IiM0NTQ1NDUiLz4KPHBhdGggZD0iTTQxIDEzLjRIMzkuMlYxMi4yQzM4LjkgMTMuMSAzOC4yIDEzLjYgMzcuMSAxMy42QzM1LjYgMTMuNiAzNC42IDEyLjYgMzQuNiAxMVY2LjVIMzYuNVYxMC41QzM2LjUgMTEuNCAzNyAxMS45IDM3LjggMTEuOUMzOC42IDExLjkgMzkuMiAxMS4zIDM5LjIgMTAuNFY2LjVINDFWMTMuNFoiIGZpbGw9IiM0NTQ1NDUiLz4KPHBhdGggZD0iTTQyLjIgNi41SDQ0VjcuN0M0NC4yIDYuOCA0NC44IDYuNCA0NS42IDYuNEM0NS44IDYuNCA0NiA2LjQgNDYuMSA2LjVWOC4xQzQ2LjEgOC4xIDQ1LjggOCA0NS42IDhDNDQuNyA4IDQ0LjEgOC42IDQ0LjEgOS41VjEzLjNINDIuMlY2LjVaIiBmaWxsPSIjNDU0NTQ1Ii8&#x2B;CjxwYXRoIGQ9Ik01MS4yIDEzLjRINDkuMUw0Ni43IDYuNUg0OC43TDUwLjEgMTEuN0w1MS41IDYuNUg1My41TDUxLjIgMTMuNFoiIGZpbGw9IiM0NTQ1NDUiLz4KPHBhdGggZD0iTTYwLjIgMTEuM0M2MCAxMi42IDU4LjggMTMuNSA1Ny4xIDEzLjVDNTUgMTMuNSA1My43IDEyLjEgNTMuNyA5LjlDNTMuNyA3LjcgNTUgNi4zIDU3IDYuM0M1OSA2LjMgNjAuMyA3LjcgNjAuMyA5LjdWMTAuM0g1NS42VjEwLjRDNTUuNiAxMS40IDU2LjIgMTIuMSA1Ny4yIDEyLjFDNTcuOSAxMi4xIDU4LjQgMTEuOCA1OC42IDExLjJINjAuMlYxMS4zWk01NS42IDkuM0g1OC41QzU4LjUgOC40IDU3LjkgNy44IDU3LjEgNy44QzU2LjIgNy44IDU1LjYgOC40IDU1LjYgOS4zWiIgZmlsbD0iIzQ1NDU0NSIvPgo8cGF0aCBkPSJNNjEuMiAxNS45VjE0LjVDNjEuMyAxNC41IDYxLjYgMTQuNSA2MS43IDE0LjVDNjIuNCAxNC41IDYyLjcgMTQuMyA2Mi44IDEzLjdMNjIuOSAxMy40TDYwLjUgNi41SDYyLjZMNjQgMTEuOUw2NS41IDYuNUg2Ny41TDY1LjEgMTMuNUM2NC41IDE1LjMgNjMuNyAxNS45IDYxLjkgMTUuOUM2MS44IDE2IDYxLjIgMTYgNjEuMiAxNS45WiIgZmlsbD0iIzQ1NDU0NSIvPgo8L3N2Zz4K" alt="Survey Solutions" width=120 /></a>"' _n


end

program define _writeToc
    version 18.0
	syntax anything , language(string)

	frame rapor_lng : python: setLanguage("`language'")
	
	python: Macro.setLocal("allvars", Q.all)
	
	file write `anything' `"<H2>`txt_table_of_contents'</H2>"' _n
	file write `anything' `"<UL>"' _n
	foreach v in `allvars' {
		python: Macro.setLocal("qt", Q.titles["`v'"])
		file write `anything' `"<LI><A href="#`v'">`qt'</A></LI>"' _n
	}
	file write `anything' `"</UL>"' _n
end


program define _writeQuestionHeader
	version 18.0
	syntax anything, question(string)
	
	python: Macro.setLocal("t",Q.getQuestionTitle("`question'"))
	file write `anything' `"<div class="pagebreak"> </div>"' _n
	file write `anything' `"<A name="`question'"><H2><FONT face="`fontname'">`question': `t' </FONT></H2>"' _n
end

// END OF FILE
