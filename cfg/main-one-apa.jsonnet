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

function(depofile, apaid=0) 
    local apaname = std.toString(apaid);
    local basename = depofile[:std.length(depofile)-8];
    local origfile = basename + "-orig" + apaname + ".tar.bz2";
    local gaussfile = basename + "-gauss" + apaname + ".tar.bz2";
    local wienerfile = basename + "-wiener" + apaname + ".tar.bz2";
    local dnnspfile = basename + "-dnnsp" + apaname + ".tar.bz2";

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
    local orig = "orig%d"%apaid;
    local gauss = "gauss%d"%apaid;
    local wiener = "wiener%d"%apaid;
    local nfsp = [

        pg.fan.tap('FrameFanout', 
                   io.frame_sink(orig, origfile, tags=[orig], digitize=true),
                   orig),

        nf(anode, robjs_sigproc.fr, chndb_perfect,
           params.daq.nticks, params.daq.tick),

        sp(anode, robjs_sigproc.fr, robjs_sigproc.er, spfilt, adcpermv,
           // override={
           //     sparse: true,
           //     use_roi_debug_mode: true,
           //     use_multi_plane_protection: true,
           //     process_planes: [0, 1, 2]
           // }
          ),

        pg.fan.tap('FrameFanout',
                   io.frame_sink(gauss, gaussfile, tags=[gauss], digitize=false),
                   gauss),

        pg.fan.tap('FrameFanout',
                   io.frame_sink(wiener, wienerfile, tags=[wiener], digitize=false),
                   wiener),
    ];

    local tscr = pg.pnode({
        type: "TorchScript",
        name: apaname,
        data: {
            model:"unet-l23-cosmic500-e50.ts",
            gpu: false,
        },
    }, nin=1, nout=1);
    local tsrv = {
        type: "TorchService",
        name: apaname,
        data: {
            model:"unet-l23-cosmic500-e50.ts",
            device: "gpucpu",
            concurrency: 1,     // 0 means no concurency (only one thread)
        },
    };
    //local ts = {obj:tsrv, tn:wc.tn(tsrv)};
    local ts = {obj:tscr, tn:tscr.name};
    local dnntag = 'dnnsp%d'%apaid;
    local dnnroi = pg.pnode({
        type: "DNNROIFinding",
        name: apaname,
        data: {
            anode: wc.tn(anode),
            intags: ['loose_lf%d'%apaid, 'mp2_roi%d'%apaid, 'mp3_roi%d'%apaid],
            outtag: dnntag,
            // Note, it is very much NOT idiomatic to tell one node about another!
            // Here, we rely on the fact that a pnode uses wc.tn() to form its name.
            torch_script: ts.tn
        }
    }, nin=1, nout=1, uses=[ts.obj]);
    local dnnsink = io.frame_sink(dnntag, dnnspfile, tags=[dnntag], digitize=false);
    local dnn = [dnnroi, dnnsink];

    local graph = pg.pipeline([depos, drifter, sim] + nfsp + dnn);

    tz.main(graph, 'TbbFlow', ['WireCellPytorch'])
