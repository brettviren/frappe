# Configure WC/LS to dump out depos

local g = import 'pgraph.jsonnet';
local wc = import 'wirecell.jsonnet';

local deposrc = g.pnode({
    type: 'wclsSimDepoSource',
    data: {
        art_tag: std.extVar("depo_input_label"), // "IonAndScint"
    },
}, nin=0, nout=1);

local deposaver = g.pnode({
    # fixme: need DepoFileSink! this saves in uncompressed zip form
    type: 'NumpyDepoSaver',
    data: {
        filename: std.extVar("depo_file_name"),
    },
}, nin=1, nout=1);

local deposink = g.pnode({ type: 'DumpDepos' }, nin=1, nout=0);

local graph = g.pipeline([deposrc, deposaver, deposink]);

local app = {
  type: 'Pgrapher',
  data: {
    edges: g.edges(graph),
  },
};

g.uses(graph) + [app]

