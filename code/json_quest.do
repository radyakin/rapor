
clear all

python:

import json

def traverse(node):
  if (node['Children']!=None):
    for s in node['Children']:
      if (s['\$type']=="SingleQuestion"):
        print(" "+s['VariableName']+":"+s['QuestionText'])
      if (s['\$type']=="Group"):
        traverse(s)

def proc(fname):
    
  print("Hello World!")
  
  with open(fname, 'r') as f:
    Q = json.load(f)  

  C=Q['Children']
  for sect in C:
    print("======"+sect['Title']+"======")
    # print(sect)

    if (sect['Children']!=None):
      for s in sect['Children']:
        if (s['\$type']=="SingleQuestion"):
          print(" "+s['VariableName']+":"+s['QuestionText'])
        if (s['\$type']=="Group"):
          if (s['IsRoster']!=1):
            traverse(s)
end

python: proc("c:/Temp/4/Questionnaire/content/document.json")


// end of file
