(() => {
  "use strict";
  const M=window.RykoLevelModel, STORAGE_KEY="ryko-level-editor-v1", ARMED_KEY="ryko-mechanic-armed", SCROLL_KEY="ryko-editor-scroll-y", toolbox=document.getElementById("toolbox"), boardGrid=document.getElementById("boardGrid"), clearBoardButton=document.getElementById("clearBoardButton");
  if(!M?.__mechanicsExtended||!toolbox||!boardGrid)return;
  const GL={up:"↑",up_right:"↗",right:"→",down_right:"↘",down:"↓",down_left:"↙",left:"←",up_left:"↖"};
  let armed=sessionStorage.getItem(ARMED_KEY)||null;
  const style=document.createElement("style"); style.textContent=`.mechanics-panel{margin-top:10px}.mechanic-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin:8px 0}.mechanic-tool{min-height:48px}.mechanic-tool.active{outline:2px solid var(--aqua)}.mechanic-mark{position:absolute;inset:12%;z-index:9;display:grid;place-items:center;border:2px solid var(--aqua);border-radius:50%;background:rgba(7,20,25,.9);font-weight:900;pointer-events:none}.mechanic-shield{position:absolute;inset:5%;z-index:8;pointer-events:none}.mechanic-shield.top{border-top:5px solid #f2e3bb}.mechanic-shield.right{border-right:5px solid #f2e3bb}.mechanic-shield.bottom{border-bottom:5px solid #f2e3bb}.mechanic-shield.left{border-left:5px solid #f2e3bb}.mechanic-laser-layer{position:absolute;inset:0;width:100%;height:100%;z-index:7;pointer-events:none}.mechanic-laser-line{stroke:#ff4058;stroke-width:7;vector-effect:non-scaling-stroke}.mechanics-list{margin:7px 0}.mechanics-list-item{display:flex;justify-content:space-between;gap:6px;align-items:center}`; document.head.appendChild(style);
  const wrap=document.createElement("section"); wrap.className="mechanics-panel"; wrap.innerHTML=`<div class="section-rule"></div><div class="panel-title">Mechanics</div><div class="selection-name">LAUNCHER</div><div class="mechanic-grid" id="dirGrid"></div><div id="launcherList" class="validation-list mechanics-list"></div><div class="section-rule"></div><div class="selection-name">DIRECTIONAL SHIELD</div><div class="check-grid" id="shieldSides">${M.MECHANIC_SIDES.map(s=>`<label><input type="checkbox" value="${s}" ${s==='top'?'checked':''}>${s}</label>`).join('')}</div><button class="button secondary small" data-arm="shield">Place shield on cell</button><div id="shieldList" class="validation-list mechanics-list"></div><div class="section-rule"></div><div class="selection-name">SWITCH → LASER</div><label class="field">Target laser ID<input id="switchTarget" placeholder="laser_1"></label><div class="field-row"><label class="field">Action<select id="switchAction"><option value="disable">Disable</option><option value="enable">Enable</option></select></label><label class="field">Seconds (0=permanent)<input id="switchDuration" type="number" min="0" step="0.1" value="0"></label></div><button class="button secondary small" data-arm="switch">Place switch</button><div id="switchList" class="validation-list mechanics-list"></div><div class="section-rule"></div><div class="selection-name">PORTAL PAIR</div><label class="field">Pair ID<input id="portalPair" value="pair_1"></label><p class="muted-copy">Arm portal, then click two cells. Balls preserve direction and speed.</p><button class="button secondary small" data-arm="portal">Place portal</button><div id="portalList" class="validation-list mechanics-list"></div><div class="section-rule"></div><div class="selection-name">TIMED LASER</div><div class="field-row"><label class="field">From X<input id="laserFromX" type="number" min="0" max="1" step=".05" value="0"></label><label class="field">From Y<input id="laserFromY" type="number" min="0" max="1" step=".05" value=".5"></label></div><div class="field-row"><label class="field">To X<input id="laserToX" type="number" min="0" max="1" step=".05" value="1"></label><label class="field">To Y<input id="laserToY" type="number" min="0" max="1" step=".05" value=".5"></label></div><div class="field-row"><label class="field">ON sec<input id="laserOnSeconds" type="number" min=".05" step=".05" value="1.5"></label><label class="field">OFF sec<input id="laserOffSeconds" type="number" min=".05" step=".05" value="1"></label></div><div class="field-row"><label class="field">Delay<input id="laserStartDelay" type="number" min="0" step=".05" value="0"></label><label class="field">Starts<select id="laserStartsOn"><option value="on">ON</option><option value="off">OFF</option></select></label></div><button class="button secondary small" id="addLaser">+ Add laser</button><div id="laserList" class="validation-list mechanics-list"></div>`; toolbox.insertAdjacentElement("afterend",wrap);
  const $=id=>document.getElementById(id), read=()=>{try{const x=localStorage.getItem(STORAGE_KEY);if(x)return M.normalizeLevel(JSON.parse(x));}catch{}return M.createDefaultLevel()}, rememberSession=()=>{if(armed)sessionStorage.setItem(ARMED_KEY,armed);else sessionStorage.removeItem(ARMED_KEY);sessionStorage.setItem(SCROLL_KEY,String(window.scrollY))}, save=l=>{rememberSession();localStorage.setItem(STORAGE_KEY,JSON.stringify(M.normalizeLevel(l)));location.reload()}, next=(a,p)=>{let i=1;while(a.some(x=>x.id===`${p}_${i}`))i++;return `${p}_${i}`};
  function item(text,del){const r=document.createElement('div');r.className='validation-item mechanics-list-item';const s=document.createElement('span');s.textContent=text;const b=document.createElement('button');b.className='button danger small';b.textContent='Delete';b.onclick=del;r.append(s,b);return r}
  function topRowGrid(){return document.getElementById('topRowGrid')}
  function cell(c,r){return r===-1?topRowGrid()?.querySelector(`.board-cell[data-column="${c}"]`):boardGrid.querySelector(`.board-cell[data-column="${c}"][data-row="${r}"]`)}
  function render(){const l=read();const dg=$('dirGrid');dg.innerHTML='';M.MECHANIC_DIRECTIONS.forEach(d=>{const b=document.createElement('button');b.className=`button ghost small mechanic-tool ${armed===`launcher:${d}`?'active':''}`;b.textContent=GL[d];b.onclick=()=>{armed=`launcher:${d}`;sessionStorage.setItem(ARMED_KEY,armed);render()};dg.append(b)}); document.querySelectorAll('.mechanic-mark,.mechanic-shield').forEach(n=>n.remove()); boardGrid.querySelectorAll(':scope>.mechanic-laser-layer').forEach(n=>n.remove());
    l.mechanics.launchers.forEach(x=>mark(x,GL[x.direction])); l.mechanics.switches.forEach(x=>mark(x,'S')); l.mechanics.portals.forEach(x=>mark(x,'◎'));
    l.mechanics.shields.forEach(x=>{const c=cell(x.column,x.row);if(c)x.sides.forEach(s=>{const d=document.createElement('div');d.className=`mechanic-shield ${s}`;c.append(d)})});
    if(l.mechanics.lasers.length){const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('class','mechanic-laser-layer');svg.setAttribute('viewBox','0 0 1000 1000');svg.setAttribute('preserveAspectRatio','none');l.mechanics.lasers.forEach(x=>{const ln=document.createElementNS('http://www.w3.org/2000/svg','line');['x1','y1','x2','y2'].forEach((k,i)=>ln.setAttribute(k,String([x.from.x,x.from.y,x.to.x,to.y][i]*1000)));ln.setAttribute('class','mechanic-laser-line');svg.append(ln)});boardGrid.append(svg)}
    lists(l);
  }
  function mark(x,t){const c=cell(x.column,x.row);if(!c)return;const d=document.createElement('div');d.className='mechanic-mark';d.textContent=t;c.append(d)}
  function lists(l){[['launcherList','launchers',x=>`${x.id} ${GL[x.direction]} C${x.column+1} ${x.row===-1?'TOP':`R${x.row+1}`}`],['shieldList','shields',x=>`${x.id} [${x.sides.join(',')}] C${x.column+1} R${x.row+1}`],['switchList','switches',x=>`${x.id} → ${x.targetId} ${x.action}`],['portalList','portals',x=>`${x.id} ${x.pairId} C${x.column+1} R${x.row+1}`],['laserList','lasers',x=>`${x.id} ${x.onSeconds}s/${x.offSeconds}s`]].forEach(([host,key,label])=>{const h=$(host);h.innerHTML='';l.mechanics[key].forEach(x=>h.append(item(label(x),()=>{const f=read();f.mechanics[key]=f.mechanics[key].filter(y=>y.id!==x.id);save(f)})))})}
  document.querySelectorAll('[data-arm]').forEach(b=>b.onclick=()=>{armed=b.dataset.arm;sessionStorage.setItem(ARMED_KEY,armed);render()});

  function resolvePlacementCell(e){
    const direct=e.target instanceof Element?e.target.closest('.board-cell'):null;
    const top=topRowGrid();
    if(direct&&(boardGrid.contains(direct)||top?.contains(direct)))return direct;
    if(typeof e.clientX!=='number'||typeof e.clientY!=='number')return null;
    const candidates=[...(top?.querySelectorAll('.board-cell')||[]),...boardGrid.querySelectorAll('.board-cell')];
    for(const candidate of candidates){const rect=candidate.getBoundingClientRect();if(e.clientX>=rect.left&&e.clientX<=rect.right&&e.clientY>=rect.top&&e.clientY<=rect.bottom)return candidate}
    return null;
  }

  function placeArmedMechanic(e){
    if(!armed)return;
    const c=resolvePlacementCell(e);if(!c)return;
    const l=read(),board=M.boardForLevel(l),col=Number(c.dataset.column),isTop=topRowGrid()?.contains(c),row=isTop?-1:Number(c.dataset.row);
    if(!Number.isInteger(col)||col<0||col>=board.columns||(!isTop&&(!Number.isInteger(row)||row<0||row>=board.rows)))return;
    if(isTop&&!armed.startsWith('launcher:'))return;
    e.preventDefault();e.stopImmediatePropagation();
    if(armed.startsWith('launcher:')){
      l.mechanics.launchers=l.mechanics.launchers.filter(x=>!(x.column===col&&x.row===row));
      l.mechanics.launchers.push({id:next(l.mechanics.launchers,'launcher'),column:col,row,direction:armed.split(':')[1]});
    }else if(armed==='shield'){
      const sides=[...document.querySelectorAll('#shieldSides input:checked')].map(x=>x.value);if(!sides.length)return alert('Select at least one protected side.');
      l.mechanics.shields=l.mechanics.shields.filter(x=>!(x.column===col&&x.row===row));
      l.mechanics.shields.push({id:next(l.mechanics.shields,'shield'),column:col,row,sides});
    }else if(armed==='switch'){
      const target=$('switchTarget').value.trim();if(!target)return alert('Set target laser ID.');
      l.mechanics.switches=l.mechanics.switches.filter(x=>!(x.column===col&&x.row===row));
      l.mechanics.switches.push({id:next(l.mechanics.switches,'switch'),column:col,row,targetId:target,action:$('switchAction').value,durationSeconds:Math.max(0,+$('switchDuration').value||0)});
    }else if(armed==='portal'){
      const pairId=$('portalPair').value.trim()||'pair_1';if(l.mechanics.portals.filter(x=>x.pairId===pairId).length>=2)return alert('This portal pair already has two endpoints.');
      l.mechanics.portals.push({id:next(l.mechanics.portals,'portal'),pairId,column:col,row});
    }
    save(l);
  }

  document.addEventListener('click',placeArmedMechanic,true);
  clearBoardButton?.addEventListener('click',event=>{
    event.preventDefault();event.stopImmediatePropagation();
    if(!window.confirm('Clear the entire initial board, top row and mechanics?'))return;
    const l=read();l.initialBoard=[];l.topRow=[];l.mechanics={launchers:[],lasers:[],shields:[],switches:[],portals:[]};armed=null;sessionStorage.removeItem(ARMED_KEY);localStorage.setItem(STORAGE_KEY,JSON.stringify(M.normalizeLevel(l)));location.reload();
  },true);
  $('addLaser').onclick=()=>{const ids=['laserFromX','laserFromY','laserToX','laserToY','laserOnSeconds','laserOffSeconds','laserStartDelay'],v=ids.map(id=>+$(`${id}`).value);if(v.some(Number.isNaN)||v[0]<0||v[0]>1||v[1]<0||v[1]>1||v[2]<0||v[2]>1||v[3]<0||v[3]>1||v[4]<=0||v[5]<=0||v[6]<0)return alert('Invalid laser values.');const l=read();l.mechanics.lasers.push({id:next(l.mechanics.lasers,'laser'),from:{x:v[0],y:v[1]},to:{x:v[2],y:v[3]},onSeconds:v[4],offSeconds:v[5],startDelay:v[6],startsOn:$('laserStartsOn').value==='on'});save(l)};
  new MutationObserver(ms=>{if(ms.some(m=>[...m.addedNodes].some(n=>n instanceof Element&&(n.matches('.board-cell')||n.querySelector?.('.board-cell')))))queueMicrotask(render)}).observe(boardGrid,{childList:true,subtree:true}); render();
  const savedScroll=Number(sessionStorage.getItem(SCROLL_KEY));if(Number.isFinite(savedScroll)){sessionStorage.removeItem(SCROLL_KEY);requestAnimationFrame(()=>requestAnimationFrame(()=>window.scrollTo(0,savedScroll)))}
})();
