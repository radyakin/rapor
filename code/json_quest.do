
clear all

python:

import json

foundfields=""

def foundq(s):
  global foundfields
  print(" "+s['VariableName']+":"+s['QuestionText'])
  foundfields=foundfields+" "+s['VariableName']

def traverse(node):
  if (node['Children']!=None):
    for child in node['Children']:
      if (child['\$type']=="SingleQuestion"):
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
    print("======"+oneSection['Title']+"======")
    traverse(oneSection)
	
  return(foundfields)
end

python: print(proc("c:/Temp/4/Questionnaire/content/document.json"))

// end of file
