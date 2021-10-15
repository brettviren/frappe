/* 
   Configure to run one APA through sim+sigproc with DNN ROI
   
   This takes as input a depos file, produces a frame file.
 
   It requires toyzero/cfg/ in the path.
 */

local wc = import "wirecell.jsonnet";
local pg = import "pgraph.jsonnet";

local tz = import "toyzero.jsonnet";
local io = import "ioutils.jsonnet";
local nf = import "nf.jsonnet";
local sp = import "sp.jsonnet";

local params = import "pgrapher/experiment/pdsp/simparams.jsonnet";
local spfilt = import "pgrapher/experiment/pdsp/sp-filters.jsonnet";
local chndb = import "pdsp_chndb.jsonnet";

local resps_sim = "dune-garfield-1d565.json.bz2";
local resps_sigproc = resps_sim;
local wires = "protodune-wires-larsoft-v4.json.bz2";
local noisef = "protodune-noise-spectra-v1.json.bz2";

function(depofile, gaussfile, dnnroifile, apaid=0) 
    local apaname = std.toString(apaid);

    local depos = io.depo_source(depofile);
    local wireobj = tz.wire_file(wires);
    local anodes = tz.anodes(wireobj, params.det.volumes);
    local anode = anodes[apaid];
    local robjs_sim = tz.responses(resps_sim, params.elec, params.daq);
    local robjs_sigproc = tz.responses(resps_sigproc, params.elec, params.daq);
    local random = tz.random([0,1,2,3,4]);
    local drifter = tz.drifter(params.det.volumes, params.lar, random);
    local chndb_perfect =
        chndb.perfect(anode, robjs_sim.fr,
                      params.daq.nticks,
                      params.daq.tick);
    local sim =
        tz.sim(anode,               // kitchen
               robjs_sim.pirs,      // sink
               params.daq,
               params.adc,
               params.lar,
               noisef,
               'adc',
               random);
    local adcpermv = tz.adcpermv(params.adc);
    local gauss = "gauss%d"%apaid;
    local nfsp = [
        nf(anode, robjs_sigproc.fr, chndb_perfect,
           params.daq.nticks, params.daq.tick),
        sp(anode, robjs_sigproc.fr, robjs_sigproc.er, spfilt, adcpermv),
        io.frame_tap(gauss,
                     io.frame_sink(gauss, gaussfile, tags=[gauss], digitize=true),
                     gauss, false),
    ];

    local ts = pg.pnode({
        type: "TorchScript",
        name: apaname,
        data: {
            model:"unet-l23-cosmic500-e50.ts",
            gpu: false,
        },
    }, nin=1, nout=1);
    local dnntag = 'dnn_sp%d'%apaid;
    local dnnroi = pg.pnode({
        type: "DNNROIFinding",
        name: apaname,
        data: {
            anode: wc.tn(anode),
            intags: ['loose_lf%d'%apaid, 'mp2_roi%d'%apaid, 'mp3_roi%d'%apaid],
            outtag: dnntag,
            // Note, it is very much NOT idiomatic to tell one node about another!
            // Here, we rely on the fact that a pnode uses wc.tn() to form its name.
            torch_script: ts.name
        }
    }, nin=1, nout=1, uses=[ts]);
    local dnnsink = io.frame_sink(dnntag, dnnroifile, tags=[dnntag], digitize=true);
    local dnn = [dnnroi, dnnsink];

    local graph = pg.pipeline([depos, drifter + sim] + nfsp + dnn);

    local plugins = [
        "WireCellSio",
        "WireCellGen", "WireCellSigProc", 
        "WireCellApps", "WireCellTbb", "WireCellPytorch"];

    local appcfg = {
        type: 'TbbFlow',
        data: {
            edges: pg.edges(graph)
        },
    };
    local cmdline = {
        type: "wire-cell",
        data: {
            plugins: plugins,
            apps: [appcfg.type]
        }
    };
    [cmdline] + pg.uses(graph) + [appcfg]
