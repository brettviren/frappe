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
local dnnroi = import "dnnroi.jsonnet";
local per_anode = import "per-anode.jsonnet";

local dets = import "dets.jsonnet";
local det = dets.pdsp;

// set scale to -1 if depos are from larsoft and +1 if following WCT
// convention.
function(depofile, apaid=0, scale=-1.0) 

    local depos = io.depo_source(depofile, scale=scale);

    local random = tz.random([0,1,2,3,4]);
    local drifter = tz.drifter(det.params.det.volumes, det.params.lar, random);
    local wireobj = tz.wire_file(det.wires);
    local anodes = tz.anodes(wireobj, det.params.det.volumes);

    local basename = depofile[:std.length(depofile)-8];

    local one_anode(anode) = 
        local apaid = anode.data.ident;
        local apaname = std.toString(apaid);
        local filename(kind) = basename + "-" + kind + apaname + ".tar.bz2";

        local pa = per_anode(anode, det);

        local orig = "orig%d"%apaid;
        local sim = [
            pa.sim(random),
            pa.frame_tap(orig, filename("orig"), true),
        ];

        local adcpermv = tz.adcpermv(det.params.adc);
        local gauss = "gauss%d"%apaid;
        local wiener = "wiener%d"%apaid;
        local nfsp = [
            pa.nf,
            pa.sp(true),
            pa.frame_tap(gauss, filename("gauss")),
            pa.frame_tap(wiener, filename("wiener")),
        ];

        // the DNN-ROI subgraph
        local ts = {
            type: "TorchService",
            name: "dnnroi",
            data: {
                model: "unet-l23-cosmic500-e50.ts",
                device: "cpu",
                concurrency: 1,
            },
        };

        local dnntag = "dnnsp%d" % apaid;
        
        local dnn = [
            // WARNING: a non-unity output scale is a total bodge to
            // make up for something wrong with the DNN-ROI model.  It
            // was chosen by looking at a simulated cosmic muon event
            // and comparing total dnnsp charge to gauss charge.
            pa.dnnsp(ts, output_scale=1.2),
            pa.frame_tap(dnntag, filename("dnnsp")),
        ];
        sim + nfsp + dnn;

    local pipe = one_anode(anodes[apaid]);
    local graph = pg.pipeline([depos, drifter] + pipe);

    tz.main(graph, 'TbbFlow', ['WireCellPytorch'])
