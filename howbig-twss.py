#!/usr/bin/env python
'''
A version of RootIOTest.howBig that works with xrootd.
Works outside of nuwa and works on non-xrootd files.

Usages: 

howbig-twss.py root://daya0001//xrootd/FMCP11a/outputs/FMCP11a_Co60-PMT_DayaBayAD1_RACF_D30830.root

howbig-twss.py out/FMCP11a_IBD_DayaBayAD1_DayaBay_IHEP_10000.root 
...
                GenHeader: raw =       543900   543.90 KiB   0.77%    comp =       159448   159.45 KiB   0.50%
                JobHeader: raw =         2599     2.60 KiB   0.00%    comp =         2074     2.07 KiB   0.01%
             RandomHeader: raw =       204529   204.53 KiB   0.29%    comp =        69287    69.29 KiB   0.22%
     RegistrationSequence: raw =        91986    91.99 KiB   0.13%    comp =        11713    11.71 KiB   0.04%
                RunHeader: raw =         1631     1.63 KiB   0.00%    comp =         1629     1.63 KiB   0.01%
                SimHeader: raw =     59154690    59.15 MiB  83.50%    comp =     30142155    30.14 MiB  95.21%
         SimReadoutHeader: raw =     10845443    10.85 MiB  15.31%    comp =      1273819     1.27 MiB   4.02%
                    Total: raw =     70844778    70.84 MiB 100.00%    comp =     31660125    31.66 MiB 100.00%

'''

from ROOT import *
from collections import defaultdict

def visit_dir(start,visitor):
    '''Visit the objects in the starting directory "start" by calling
    visitor(obj) on each and descending if obj is a TDirectory'''
    start.cd()
    it = TIter(start.GetListOfKeys())
    while True:
        key = it()
        if not key: break;
        obj = key.ReadObj()
        visitor(obj)
        if obj.IsA().InheritsFrom("TDirectory"):
            visit_dir(obj,visitor)
        continue
    return

class HowBig:
    '''
    A TDirectory Visitor that looks for TTrees and collects
    information on how big they are.
    '''

    def __init__(self,name = 'HowBig'):
        self.trees = {}
        self.branches = defaultdict(dict)
        self.name = name        # for string
        return

    def __call__(self,obj):
        '''
        Implement the TDirectory Visitor interface, called with an TObject
        '''
        name = obj.GetName()

        if not obj.IsA().InheritsFrom('TTree'):
            #print ('I do not care about non-tree (%s) object "%s"' % (obj.IsA().GetName(), name))
            return

        self.trees[name] = (obj.GetTotBytes(), obj.GetZipBytes(), -1, -1, obj.GetEntries())
        it = TIter(obj.GetListOfBranches())
        while True:
            bobj = it()
            if not bobj: break;
            bname = bobj.GetName()
            btype = bobj.GetType()
            print ("BRANCH: %d %d %s %s" % (bobj.GetTotBytes(), bobj.GetZipBytes(), bname, btype))
            self.branches[name][bname] = (bobj.GetTotBytes(), bobj.GetZipBytes(), bobj.GetEntries())
        
        return

    def _pretty(self,bytes):
        sizes = [('GiB',1000000000),
                 ('MiB',1000000),
                 ('KiB',1000)]
        for unit,num in sizes:
            if 0 == bytes / num: continue
            return '%.2f %s' % (bytes / float(num) , unit)
            continue
        return '%d B' % bytes

    def _entry2str(self,name,bytes,zbytes,        percentbytes, percentzbytes, entries,
                   pattern = "%25s: raw = %12d %12s %6.2f%%  comp = %12d %12s %6.2f%%  entries = %12d"):
        'Pretty print the data'
        return pattern % (name,
                          bytes,self._pretty(bytes), percentbytes, 
                          zbytes,self._pretty(zbytes), percentzbytes, entries)
                          

    def _branch2str(self, name, totbytes, zbytes, entries,
                    pattern="%25s: raw = %12d %12s          comp = %12d %12s          entries = %12d"):
        return pattern % (name, totbytes, self._pretty(totbytes),
                          zbytes, self._pretty(zbytes), entries)

    def __str__(self):
        keys = list(self.trees.keys())
        keys.sort()
        tot = ztot = etot = 0
        ret = [self.name]

        for key in keys: # once to compute totals
            bytes,zbytes, percentbytes,percentzbytes,entries = self.trees[key]
            tot += bytes
            ztot += zbytes
            etot += entries
            continue

        for key in keys: # again to compute percentages and print
            bytes,zbytes, percentbytes,percentzbytes,entries = self.trees[key]
            if bytes == 0:
                continue
            if tot> 0 : percentbytes = float(100*bytes)/float(tot)
            if ztot>0 : percentzbytes= float(100*zbytes)/float(ztot)
            ret.append(self._entry2str(key,bytes,zbytes,percentbytes,percentzbytes,entries))
            for bname, bdat in self.branches[key].items():
                ret.append(self._branch2str(bname,*bdat))

        ret.append(self._entry2str('Total',tot,ztot,100.,100.,etot))
        return '\n'.join(ret)

if __name__ == '__main__':
    import sys
    hbs = []
    for filename in sys.argv[1:]:
        hb = HowBig(name=filename)
        tfile = TFile.Open(filename)
        visit_dir(tfile,hb)
        print (hb)
        hbs.append(hb)
        continue
    


