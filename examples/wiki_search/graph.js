// Browser services only: the independently compiled MoonBit module owns topology
// selection and layout. No perpetual simulation; opening/resetting requests a frame.
let dispose = () => {};
export function enhanceLocalGraph() {
  dispose();
  const region=document.querySelector('[data-local-graph]');
  if(!region)return;
  const slot=region.querySelector('.graph-enhancement');
  const source=region.dataset.localGraph;
  const initial=JSON.parse(source);
  const current=initial.nodes[0]?.url;
  const abort=new AbortController();let worker,started=false,sequence=0,graph;
  const on=(node,type,fn)=>node.addEventListener(type,fn,{signal:abort.signal});
  dispose=()=>{abort.abort();worker?.terminate();slot.replaceChildren();};
  const controls=document.createElement('div');controls.className='graph-tools';
  const status=document.createElement('p');status.className='graph-status';status.setAttribute('role','status');
  const ns='http://www.w3.org/2000/svg';
  const svg=document.createElementNS(ns,'svg');svg.classList.add('graph-canvas');svg.setAttribute('role','group');svg.setAttribute('aria-label','Local authored-link graph. Use note links or the linked list below.');
  const layer=document.createElementNS(ns,'g');svg.append(layer);
  let zoom=1,panX=0,panY=0,extent=180;
  const transform=()=>{layer.setAttribute('transform',`translate(${panX} ${panY}) scale(${zoom})`);const unit=extent*2/Math.max(1,Math.min(svg.clientWidth,svg.clientHeight))/zoom;for(const text of layer.querySelectorAll('text')){text.style.fontSize=`${14*unit}px`;text.setAttribute('y',String(-14*unit));}};
  const button=(label,fn)=>{const b=document.createElement('button');b.type='button';b.textContent=label;on(b,'click',fn);controls.append(b);};
  button('Zoom in',()=>{zoom=Math.min(3,zoom*1.25);transform();});
  button('Zoom out',()=>{zoom=Math.max(.5,zoom/1.25);transform();});
  for(const [label,x,y] of [['Left',30,0],['Right',-30,0],['Up',0,30],['Down',0,-30]])button(label,()=>{panX+=x;panY+=y;transform();});
  button('Reset view',()=>{zoom=1;panX=panY=0;transform();if(graph)draw();});
  const select=node=>{status.textContent=`${node.title}${node.url===current?' — current note':''}`;for(const a of layer.querySelectorAll('a'))a.classList.toggle('selected',a.dataset.url===node.url);};
  on(layer,'focusin',e=>{const slug=e.target.closest('a')?.dataset.slug;const node=graph?.nodes.find(n=>n.slug===slug);if(node)select(node);});
  on(layer,'pointerover',e=>{const slug=e.target.closest('a')?.dataset.slug;const node=graph?.nodes.find(n=>n.slug===slug);if(node)select(node);});
  let points,drag,ignoreClick=false;
  function draw(){
    layer.replaceChildren();svg.classList.toggle('graph-crowded',graph.nodes.length>12);points=new Map(graph.nodes.map(n=>[n.slug,{...n}]));
    extent=Math.max(180,...graph.nodes.flatMap(n=>[Math.abs(n.x)+90,Math.abs(n.y)+35]));
    svg.setAttribute('viewBox',`${-extent} ${-extent} ${extent*2} ${extent*2}`);
    const defs=document.createElementNS(ns,'defs');const marker=document.createElementNS(ns,'marker');let arrowId='lattice-graph-arrow';while(document.getElementById(arrowId))arrowId+='-';marker.id=arrowId;marker.setAttribute('viewBox','0 0 10 10');marker.setAttribute('refX','18');marker.setAttribute('refY','5');marker.setAttribute('markerWidth','5');marker.setAttribute('markerHeight','5');marker.setAttribute('orient','auto');const arrow=document.createElementNS(ns,'path');arrow.setAttribute('d','M 0 0 L 10 5 L 0 10 z');marker.append(arrow);defs.append(marker);layer.append(defs);
    for(const edge of graph.edges){const line=document.createElementNS(ns,'line');line.dataset.source=edge.source;line.dataset.target=edge.target;line.setAttribute('marker-end',`url(#${arrowId})`);layer.append(line);}
    for(const node of graph.nodes){
      const url=new URL(node.url,location.href);if(url.origin!==location.origin||!['http:','https:'].includes(url.protocol))continue;
      const a=document.createElementNS(ns,'a');a.setAttribute('href',url.href);a.setAttribute('aria-label',node.title);a.dataset.slug=node.slug;a.dataset.url=node.url;
      if(node.url===current)a.setAttribute('aria-current','page');
      const circle=document.createElementNS(ns,'circle');circle.setAttribute('r',node.url===current?'8':'6');
      const title=document.createElementNS(ns,'title');title.textContent=node.title;
      const text=document.createElementNS(ns,'text');text.setAttribute('y','-13');text.setAttribute('text-anchor','middle');text.textContent=Array.from(node.title).slice(0,22).join('')+(Array.from(node.title).length>22?'…':'');
      a.append(title,circle,text);layer.append(a);
    }
    position();transform();select(graph.nodes[0]);
  }
  function position(){for(const a of layer.querySelectorAll('a')){const p=points.get(a.dataset.slug);a.setAttribute('transform',`translate(${p.x} ${p.y})`);}for(const line of layer.querySelectorAll('line')){const a=points.get(line.dataset.source),b=points.get(line.dataset.target);line.setAttribute('x1',a.x);line.setAttribute('y1',a.y);line.setAttribute('x2',b.x);line.setAttribute('y2',b.y);}}
  on(svg,'pointerdown',e=>{if(e.button!==0)return;const point=new DOMPoint(e.clientX,e.clientY).matrixTransform(svg.getScreenCTM().inverse());drag={id:e.pointerId,x:point.x,y:point.y,slug:e.target.closest('a')?.dataset.slug,moved:false};});
  on(svg,'pointermove',e=>{if(!drag||drag.id!==e.pointerId)return;const point=new DOMPoint(e.clientX,e.clientY).matrixTransform(svg.getScreenCTM().inverse());const dx=point.x-drag.x,dy=point.y-drag.y;if(!drag.moved&&Math.abs(dx)+Math.abs(dy)<4)return;drag.moved=true;svg.setPointerCapture(e.pointerId);if(drag.slug){const p=points.get(drag.slug);p.x+=dx/zoom;p.y+=dy/zoom;position();}else{panX+=dx;panY+=dy;transform();}drag.x=point.x;drag.y=point.y;});
  on(svg,'pointerup',()=>{ignoreClick=drag?.moved===true;drag=null;});on(svg,'pointercancel',()=>{drag=null;});
  svg.addEventListener('click',e=>{if(ignoreClick){e.preventDefault();e.stopPropagation();ignoreClick=false;}},{capture:true,signal:abort.signal});
  function start(){
    if(started||!region.open||document.hidden)return;started=true;
    try{worker=new Worker(new URL('./graph-worker.js',import.meta.url),{type:'module'});const id=++sequence;
      worker.onmessage=({data})=>{if(data.id!==id||!region.isConnected)return;if(data.error||!data.graph?.nodes?.length){status.textContent='Graph unavailable; use the note links below.';slot.replaceChildren(status);return;}graph=data.graph;slot.replaceChildren(controls,svg,status);draw();};
      worker.onerror=()=>{status.textContent='Graph unavailable; use the note links below.';slot.replaceChildren(status);};
      worker.postMessage({id,source,current});
    }catch{status.textContent='Graph unavailable; use the note links below.';slot.replaceChildren(status);}
  }
  on(region,'toggle',()=>{if(!region.open){worker?.terminate();worker=undefined;started=false;}else start();});
  on(document,'visibilitychange',()=>{if(document.hidden){worker?.terminate();worker=undefined;started=false;}else start();});
  start();
}
