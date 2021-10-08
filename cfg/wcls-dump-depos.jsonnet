# Configure WC/LS to dump out depos

local pg = import 'pgraph.jsonnet';
local wc = import 'wirecell.jsonnet';

local graph = pg.pipeline([
    pg.pnode({
        type: 'wclsSimDepoSource',
        data: {
            art_tag: "IonAndScint"
        },
    }, nin=0, nout=1),
    
    pg.pnode({
        type: 'DepoBagger'
    }, nin=1, nout=1),

    pg.pnode({
        type: 'DepoFileSink',
        data: {
            outname: "cosmic-depos.tar.bz2"
        },
    }, nin=1, nout=1),
]);

local app = {
  type: 'TbbFlow',              // must match what used in fcl
  data: {
    edges: pg.edges(graph),
  },
};

pg.uses(graph) + [app]

