# Configure WC/LS to run simulation, save noise-free ADC

local pg = import 'pgraph.jsonnet';
local wc = import 'wirecell.jsonnet';
local params = import "pgrapher/experiment/pdsp/simparams.jsonnet";

// fixme: larwirecell needs a new component that will emit depo sets
// instead of singular depos.  Once provided, this pipeline should be
// made to colapse down to just that node.
local deposrc = pg.pipeline([
    pg.pnode({
        type: 'wclsSimDepoSource',
        data: {
            art_tag: "IonAndScint",
        },
    }, nin=0, nout=1),
    pg.pnode({
        type:'DepoBagger',
        data: {
            gate: [0, params.daq.nticks*params.daq.tick],
        },
    }, nin=1, nout=1)]);

    

local random = {
    type: "Random",
    data: {
        generator: "default",
        seeds: [1,2,3,4],
    }
};

// This depo set drifter uses the singular depo drifter to do the
// actual drifting.
local drifterone = pg.pnode({
    type: "Drifter",
    data: params.lar {
        rng: wc.tn(random),
        xregions: wc.unique_list(std.flattenArrays([v.faces for v in params.det.volumes])),
        time_offset: 0,
        fluctuate: true,
    }}, nin=1, nout=1, uses=[random]);
local drifter = pg.pnode({
    type: "DepoSetDrifter",
    data: { drifter: "Drifter" },
}, nin=1, nout=1, uses=[drifterone]);


local fr = {
    type: "FieldResponse",
    data: { filename: "dune-garfield-1d565.json.bz2" }
};
local er = {
    type: "ColdElecResponse",
    data: {
        shaping: params.elec.shaping,
        gain: params.elec.gain,
        postgain: params.elec.postgain,
        nticks: params.daq.nticks,
        tick: params.daq.tick,
    },            
};
local rc = {
    type: "RCResponse",
    data: {
        width: 1.0*wc.ms,       // in params?
        nticks: params.daq.nticks,
        tick: params.daq.tick,
    }
};
local wires = {
    type:"WireSchemaFile",
    data: {filename: "protodune-wires-larsoft-v4.json.bz2" }
};
local pirs = [{
    type: "PlaneImpactResponse",
    name: "%d"%plane,
    data : {
        plane: plane,
        field_response: wc.tn(fr),
        short_responses: [wc.tn(er)],
        // this needs to be big enough for convolving FR*CE
        overall_short_padding: 200*wc.us,
        long_responses: [wc.tn(rc)],
        // this needs to be big enough to convolve RC
        long_padding: 1.5*wc.ms,
    },
    uses: [fr, er, rc],
} for plane in [0,1,2]];

local anodes = [ {
    type: "AnodePlane",
    name: "%d" % vol.wires,
    data: {
        ident: vol.wires,
        wire_schema: wc.tn(wires),
        faces: vol.faces,
    },
    uses: [wires]
} for vol in params.det.volumes];

local sigsim(anode) = pg.pnode({
    type:'DepoTransform',
    name:'%d' % anode.data.ident,
    data: {
        rng: wc.tn(random),
        anode: wc.tn(anode),
        pirs: [wc.tn(p) for p in pirs],
        fluctuate: true,
        drift_speed: params.lar.drift_speed,
        first_frame_number: 0,
        readout_time: params.daq.nticks * params.daq.tick, 
        start_time: 0,
        tick: params.daq.tick,
        nsigma: 3,
    },
}, nin=1, nout=1, uses=pirs + [anode, random]);


local tap(anode) = pg.pnode({
    type: "FrameFileSink",
    name: "%d"%anode.data.ident,
    data: {
        outname: "signal-volts-apa%d.tar.bz2"%anode.data.ident,
        tags: [],
        digitize: false,        
    }}, nin=1, nout=0);

local pipes = [ pg.pipeline([sigsim(a), tap(a)]) for a in anodes];
local body = pg.fan.fanout('DepoSetFanout', pipes);
local graph = pg.pipeline([deposrc, drifter, body]);

local app = {
    //type: 'Pgrapher',
    type: 'TbbFlow',            // be sure to make this match in .fcl!
    data: {
        edges: pg.edges(graph),
    },
};

pg.uses(graph) + [app]
