/* 
   Configure to run all APAs through a pipeline 

   sim(adc) -> sigproc(wiener,gauss) -> dnnroi

   Example command line:

   wire-cell --threads 1 -l stderr -L debug \
     -A input=depos.tar.bz2 \
     -A taps={...} \
     -A options={...} \
     -c cfg/main-all-apa.jsonnet

   The optional "taps" data structure is used to save intermediate
   results to file.  If given it must provide a mapping from a data
   tier key word to a file pattern.  The key is one of the
   conventional tags:

   - orig :: the ADC-level frames out of the simulation
   - gauss :: the signal processing with Gaussian filter
   - wiener :: the signal processing with Wiener filter

   The tap file pattern MUST have a %d format marker which will be
   interpolated on the APA ID. 

   Example:

   wire-cell --tla-code \
       'taps={"orig":"frame-orig-apa%d.tar.bz2","gauss":"frame-gauss-apa%d.tar.bz2","img":"img-apa%d.tar.bz2"}'  \
       ...

   The optional "options" object provides various parameters that can
   override hard-wired defaults.  See below for what is available.

   This file requires WCT's and toyzero's /cfg/ in the the import
   path.  

*/


local wc = import "wirecell.jsonnet";
local pg = import "pgraph.jsonnet";

local tz = import "toyzero.jsonnet";

local defaults = {
    params: import "pgrapher/experiment/pdsp/simparams.jsonnet",
    spfilt: import "pgrapher/experiment/pdsp/sp-filters.jsonnet",
    chndb: import "pdsp_chndb.jsonnet",
    resps_sim: "dune-garfield-1d565.json.bz2",
    resps_sigproc: self.resps_sim,
    wires: "protodune-wires-larsoft-v4.json.bz2",
    noisef: "protodune-noise-spectra-v1.json.bz2",
    dnnroi: {
        model: "unet-l23-cosmic500-e50.ts",
        device: "gpu",          // cpu, gpu or gpucpu
        concurrency: 0,         // number of *extra* accesses torch beyond serial
    },
};

function(input, taps={}, options={})
    local opt = std.mergePatch(defaults, options);

    local depos = tz.io.depo_source(input);
    local wireobj = tz.wire_file(opt.wires);
    local anodes = tz.anodes(wireobj, opt.params.det.volumes);

    local robjs_sim = tz.responses(opt.resps_sim, opt.params.elec, opt.params.daq);
    local robjs_sigproc = tz.responses(opt.resps_sigproc, opt.params.elec, opt.params.daq);
    local random = tz.random([0,1,2,3,4]);
    local drifter = tz.drifter(opt.params.det.volumes, opt.params.lar, random);
    local chndb_perfect(anode) =
        opt.chndb.perfect(anode, robjs_sim.fr,
                          opt.params.daq.nticks, opt.params.daq.tick);

    // return list of nodes for tap or empty list if not requested
    local tap_out(tap, anode, cap=false) = 
        // Put tap name in comp name as we may have multiple taps of the same type and apa id.
        local apaid = anode.data.ident;
        local name = "%s%d"%[tap,apaid];
        local digi = tap == "raw" || tap == "orig";
        local sink = tz.io.frame_sink(name, taps[tap]%apaid, tags=[name], digitize=digi);
        if std.objectHas(taps, tap)
        then [tz.io.frame_tap(name, sink, name, cap)]
        else [];

    local sim(anode) = [
        tz.sim(anode,
               robjs_sim.pirs,
               opt.params.daq,
               opt.params.adc,
               opt.params.lar,
               opt.noisef,
               'adc',
               random)
    ] + tap_out("orig", anode);

    local adcpermv = tz.adcpermv(opt.params.adc);

    local nfsp(anode) = [
        tz.nf(anode, robjs_sigproc.fr, chndb_perfect(anode),
              opt.params.daq.nticks, opt.params.daq.tick)
    ] + tap_out("raw", anode) + [
        tz.sp(anode, robjs_sigproc.fr, robjs_sigproc.er, opt.spfilt, adcpermv)
    ] + tap_out("gauss", anode) + tap_out("wiener", anode);

    local ts = {
        type: "TorchService",
        data: opt.dnnroi,
    };

    local dnnroi(anode) = [
        local apaid = std.toString(anode.data.ident);
        local tname = "dnnsp" + apaid;
        pg.pnode({
            type: "DNNROIFinding",
            name: apaid,
            data: {
                anode: wc.tn(anode),
                intags: ['loose_lf'+apaid, 'mp2_roi'+apaid, 'mp3_roi'+apaid],
                outtag: tname,
                torch_script: wc.tn(ts),
            }
        }, nin=1, nout=1, uses=[ts, anode])
    ] + tap_out("dnnsp", anode, true);

    local oneapa(anode) = pg.pipeline(sim(anode) + nfsp(anode) + dnnroi(anode));
    local pipes = [oneapa(a) for a in anodes];
    local body = pg.fan.fanout('DepoSetFanout', pipes);
    local graph = pg.pipeline([depos, drifter, body]);

    tz.main(graph, 'TbbFlow', ['WireCellPytorch'])
