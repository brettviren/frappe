#!/usr/bin/env python3
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from wirecell.util import ario

chans = [0,800,1600,2560]


def get_planes(filename, tag):
    fp = ario.Reader(filename)
    arr = fp[tag]
    return [arr[f:l,:] for f,l in zip(chans[:-1], chans[1:])]


def load_gd():
    gs = get_planes("cosmic-depos-gauss0.tar.bz2", 'frame_gauss0_0')
    ds = get_planes("cosmic-depos-dnnsp0.tar.bz2", 'frame_dnnsp0_0')
    return [gs,ds]

def dump_charge(gs, ds):
    for g,d in zip(gs,ds):
        n = g.size
        gavg = np.sum(g)/n
        davg = np.sum(d)/n
        print(f'chan:[{f:4},{l:4}] gauss={gavg:8.3} dnnsp={davg:8.3} g/d ratio={gavg/davg:.3}')

def plot_diff(gs, ds, pdf_file="diff.pdf"):

    vmm=10000

    with PdfPages(pdf_file) as pdf:
        for ind,(g,d) in enumerate(zip(gs,ds)):
            gz = np.array(g)
            #gz[np.abs(gz)<1] = 1.0
            dz = np.array(d)
            #dz[np.abs(dz)<1] = 1.0
            reldiff = (gz-dz)

            for tstep in range(5):
                t1=tstep*1000
                t2=t1+1000

                plt.clf()
                plt.title(f'gauss-dnnsp difference, plane {ind}, t=[{t1}:{t2}]')
                plt.imshow(reldiff[:,t1:t2],
                           cmap='seismic', interpolation='none',
                           aspect='auto', vmin=-vmm, vmax=vmm)
                plt.colorbar()
                pdf.savefig(dpi=600)
    print(pdf_file)
        
def plot_mask(gs, ds, pdf_file="mask.pdf"):

    thresh=10
    cmap = plt.get_cmap('gist_rainbow').copy()
    cmap.set_bad(color='black')

    with PdfPages(pdf_file) as pdf:
        for ind,(g,d) in enumerate(zip(gs,ds)):
            gm = np.ma.array(g, mask=g<=thresh)
            dm = np.ma.array(d, mask=d<=thresh)

            for tstep in range(5):
                t1=tstep*1000
                t2=t1+1000

                plt.clf()
                fig, axes = plt.subplots(nrows=1, ncols=2, sharey = True)

                fig.suptitle(f'masked at q={thresh}, plane {ind}, t=[{t1}:{t2}]')

                axes[0].set_title('gauss')
                im0 = axes[0].imshow(gm[:,t1:t2],  cmap=cmap, interpolation='none', aspect='auto')
                plt.colorbar(im0, ax=axes[0])

                axes[1].set_title('dnnsp')
                im1 = axes[1].imshow(dm[:,t1:t2],  cmap=cmap, interpolation='none', aspect='auto')
                plt.colorbar(im1, ax=axes[1])

                pdf.savefig(fig, dpi=600)
    print(pdf_file)

    

if '__main__' == __name__:
    import sys
    cmd = sys.argv[1]
    gs,ds = load_gd()
    if cmd == 'charge':
        dump_charge(gs,ds)
    elif cmd == 'diff':
        plot_diff(gs[:-1], ds[:-1])
    elif cmd == 'mask':
        plot_mask(gs[:-1], ds[:-1])        
