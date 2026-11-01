import { layout_graph } from './graph-core.js';
self.onmessage = ({data}) => {
  try { self.postMessage({id:data.id, graph:JSON.parse(layout_graph(data.source,data.current))}); }
  catch { self.postMessage({id:data.id,error:true}); }
};
