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

// set scale to -1 if depos are from larsoft and +1 if following WCT
// convention.
function(depofile, apaid=0, scale=-1.0) 
    local apaname = std.toString(apaid);
    local basename = depofile[:std.length(depofile)-8];
    local origfile = basename + "-orig" + apaname + ".tar.bz2";
    local gaussfile = basename + "-gauss" + apaname + ".tar.bz2";
    local wienerfile = basename + "-wiener" + apaname + ".tar.bz2";
    local dnnspfile = basename + "-dnnsp" + apaname + ".tar.bz2";

    local depos = io.depo_source(depofile, scale=scale);
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
    local apa_dense = {chbeg:0,   chend:2560, tbbeg:0, tbend:params.daq.nticks};
    local upl_dense = {chbeg:0,   chend:800 , tbbeg:0, tbend:params.daq.nticks};
    local vpl_dense = {chbeg:800, chend:1600, tbbeg:0, tbend:params.daq.nticks};
    local nfsp = [

        pg.fan.tap('FrameFanout', 
                   io.frame_sink(orig, origfile, tags=[orig],
                                 digitize=true, dense=apa_dense),
                   orig),

        nf(anode, robjs_sigproc.fr, chndb_perfect,
           params.daq.nticks, params.daq.tick),

        sp(anode, robjs_sigproc.fr, robjs_sigproc.er, spfilt, adcpermv,
           override={
               sparse: true,
               use_roi_debug_mode: true,
               use_multi_plane_protection: true,
               process_planes: [0, 1, 2]
           }
          ),

        pg.fan.tap('FrameFanout',
                   io.frame_sink(gauss, gaussfile, tags=[gauss],
                                 digitize=false, dense=apa_dense),
                   gauss),

        pg.fan.tap('FrameFanout',
                   io.frame_sink(wiener, wienerfile, tags=[wiener],
                                 digitize=false, dense=apa_dense),
                   wiener),
    ];

    local ts = {
        type: "TorchService",
        name: apaname,
        data: {
            model:"unet-l23-cosmic500-e50.ts",
            device: "cpu",
            concurrency: 1,     // 0 means no concurency (only one thread)
        },
    };

    local dnnroi_u = pg.pnode({
        type: "DNNROIFinding",
        name: apaname+"u",
        data: {
            anode: wc.tn(anode),
            intags: ['loose_lf%d'%apaid, 'mp2_roi%d'%apaid, 'mp3_roi%d'%apaid],
            outtag: "dnnsp%du"%apaid,
            cbeg: 0,
            cend: 800,
            torch_script: wc.tn(ts)
        }
    }, nin=1, nout=1, uses=[ts]);
    local dnnroi_v = pg.pnode({
        type: "DNNROIFinding",
        name: apaname+"v",
        data: {
            anode: wc.tn(anode),
            intags: ['loose_lf%d'%apaid, 'mp2_roi%d'%apaid, 'mp3_roi%d'%apaid],
            outtag: "dnnsp%dv"%apaid,
            cbeg: 800,
            cend: 1600,
            torch_script: wc.tn(ts)
        }
    }, nin=1, nout=1, uses=[ts]);
    local dnnroi_w = pg.pnode({
        type: "ChannelSelector",
        name: "dnnsp"+apaname+"w",
        data: {
            channels: std.range(1600, 2560-1),
            tags: ["gauss%d"%apaid],
            tag_rules: [{
                frame: {".*":"DNNROIFinding"},
                trace: {["gauss%d"%apaid]:"dnnsp%dw"%apaid},
            }],
        }
    }, nin=1, nout=1);

    local dnnpipes = [dnnroi_u, dnnroi_v, dnnroi_w];
    local dnnfanout = pg.pnode({
        type: "FrameFanout",
        name: "dnnsp-pipes-%d" % apaid,
        data: {
            multiplicity: 3
        }
    }, nin=1, nout=3);

    local dnntag = "dnnsp%d" % apaid;

    local dnnfanin = pg.pnode({
        type: "FrameFanin",
        name: "dnnsp-pipes-%d" % apaid,
        data: {
            multiplicity: 3,
            tag_rules: [{
                frame: {".*":dnntag}
            } for plane in ["u", "v", "w"]]
        },
    }, nin=3, nout=1);

    local dnnsink = io.frame_sink(dnntag, dnnspfile, tags=[dnntag],
                                  digitize=false, dense=apa_dense);
    local dnn = pg.intern(innodes=[dnnfanout],
                          outnodes=[dnnfanin],
                          centernodes=dnnpipes,
                          edges=[pg.edge(dnnfanout, dnnpipes[ind], ind, 0) for ind in [0,1,2]] +
                          [pg.edge(dnnpipes[ind], dnnfanin, 0, ind) for ind in [0,1,2]]);

    local graph = pg.pipeline([depos, drifter, sim] + nfsp + [dnn, dnnsink]);

    tz.main(graph, 'TbbFlow', ['WireCellPytorch'])
