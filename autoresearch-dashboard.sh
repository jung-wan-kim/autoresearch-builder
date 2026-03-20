#!/bin/bash
# autoresearch-dashboard.sh
# JSONL 로그를 읽어서 인터랙티브 HTML 대시보드 생성 + 자동 새로고침
#
# 사용법: ~/.claude/scripts/autoresearch-dashboard.sh [jsonl_path]
# 기본값: .claude/logs/autoresearch.jsonl

JSONL="${1:-.claude/logs/autoresearch.jsonl}"
OUT="/tmp/autoresearch-dashboard.html"
JSONL_ABS="$(cd "$(dirname "$JSONL")" 2>/dev/null && pwd)/$(basename "$JSONL")"

if [ ! -f "$JSONL" ]; then
  echo "파일 없음: $JSONL"
  exit 1
fi

DATA=$(grep 'experiment_done' "$JSONL" 2>/dev/null | python3 -c "
import sys, json
rows = []
for line in sys.stdin:
    try:
        d = json.loads(line.strip())
        if d.get('action') != 'experiment_done': continue
        det = d.get('details', {})
        rows.append({
            'time': d.get('local_time', ''),
            'commit': det.get('commit', ''),
            'status': det.get('status', ''),
            'metric': det.get('metric', ''),
            'value': det.get('value', 0),
            'prev': det.get('prev'),
            'delta': det.get('delta'),
            'description': det.get('description', ''),
            'memory_gb': det.get('memory_gb'),
            'tag': det.get('tag', '')
        })
    except: pass
print(json.dumps(rows))
" 2>/dev/null)

if [ -z "$DATA" ] || [ "$DATA" = "[]" ]; then
  echo "experiment_done 로그 없음: $JSONL"
  exit 1
fi

COUNT=$(echo "$DATA" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
echo "실험 ${COUNT}건 로드됨"

cat > "$OUT" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Autoresearch Dashboard</title>
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;400;500;700&family=Newsreader:ital,wght@0,300;0,700;1,300&family=Space+Grotesk:wght@300;400;700&display=swap" rel="stylesheet">
<style>
:root{--bg:#08090c;--surface:#0f1114;--border:#1a1d23;--bh:#2a2f38;--text:#a0a8b4;--dim:#545b67;--bright:#e8ecf1;--accent:#c8956c;--green:#8fb47a;--blue:#7c9cba;--purple:#b48fc7;--red:#c75c5c;--mono:'JetBrains Mono',monospace;--serif:'Newsreader',Georgia,serif;--sans:'Space Grotesk',sans-serif}
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:var(--sans);background:var(--bg);color:var(--text);overflow-x:hidden}
body::before{content:'';position:fixed;inset:0;z-index:9999;pointer-events:none;opacity:0.02;background-image:url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");background-size:128px}

.header{padding:48px 48px 32px;display:flex;align-items:flex-end;justify-content:space-between;border-bottom:1px solid var(--border)}
.header h1{font-family:var(--serif);font-size:2.8em;color:var(--bright);letter-spacing:-3px;line-height:1}
.header h1 em{font-weight:300;color:var(--green)}
.header-right{text-align:right}
.header-meta{font-family:var(--mono);font-size:0.68em;color:var(--dim);margin-bottom:6px}
.live-badge{font-family:var(--mono);font-size:0.68em;color:var(--green);display:flex;align-items:center;gap:6px;justify-content:flex-end}
.live-dot{width:7px;height:7px;border-radius:50%;background:var(--green);animation:pulse 2s infinite}
@keyframes pulse{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.4;transform:scale(.8)}}
.refresh-btn{font-family:var(--mono);font-size:0.65em;padding:4px 14px;background:transparent;border:1px solid var(--border);color:var(--dim);cursor:pointer;margin-top:8px;transition:all .2s}
.refresh-btn:hover{border-color:var(--green);color:var(--green)}

.content{padding:0 48px 48px}

/* Stats */
.stats{display:grid;grid-template-columns:repeat(6,1fr);gap:1px;margin:32px 0}
.stat{padding:24px 16px;background:var(--surface);border:1px solid var(--border);text-align:center;transition:border-color .3s}
.stat:hover{border-color:var(--bh)}
.stat .n{font-family:var(--serif);font-size:2.6em;font-weight:700;color:var(--bright);line-height:1;letter-spacing:-2px}
.stat .l{font-family:var(--mono);font-size:0.58em;color:var(--dim);letter-spacing:5px;margin-top:6px}
.stat.k .n{color:var(--green)}.stat.d .n{color:var(--accent)}.stat.c .n{color:var(--red)}
.stat .bar{height:3px;margin-top:10px;border-radius:0}

/* Section */
.sect{margin-top:48px}
.sect-label{font-family:var(--mono);font-size:0.62em;color:var(--accent);letter-spacing:6px;margin-bottom:8px;display:flex;align-items:center;gap:8px}
.sect-label::before{content:'';width:12px;height:1px;background:var(--accent)}
.sect-title{font-family:var(--serif);font-size:1.8em;color:var(--bright);font-weight:700;letter-spacing:-1px;margin-bottom:20px}

/* Chart */
.chart-container{position:relative;background:var(--surface);border:1px solid var(--border);padding:24px;height:320px}
.chart-container canvas{width:100%!important;height:100%!important}
.chart-tooltip{position:absolute;background:var(--bg);border:1px solid var(--border);padding:10px 14px;font-family:var(--mono);font-size:0.72em;pointer-events:none;opacity:0;transition:opacity .15s;z-index:10;min-width:180px}
.chart-tooltip .tt-status{font-weight:700;margin-bottom:4px}
.chart-tooltip .tt-row{display:flex;justify-content:space-between;gap:16px;color:var(--dim)}
.chart-tooltip .tt-val{color:var(--bright)}
.chart-legend{display:flex;gap:20px;margin-top:12px;justify-content:center}
.chart-legend span{font-family:var(--mono);font-size:0.68em;color:var(--dim);display:flex;align-items:center;gap:6px}
.chart-legend span::before{content:'';width:10px;height:10px;border-radius:50%}
.legend-keep::before{background:var(--green)}.legend-discard::before{background:var(--accent)}.legend-crash::before{background:var(--red)}

/* Table */
table{width:100%;border-collapse:collapse;font-size:0.82em}
th{font-family:var(--mono);font-size:0.65em;color:var(--accent);letter-spacing:4px;text-align:left;padding:10px 12px;border-bottom:2px solid var(--border);position:sticky;top:0;background:var(--bg);cursor:pointer;user-select:none;transition:color .2s}
th:hover{color:var(--bright)}
th.sorted{color:var(--bright)}
th.sorted::after{content:' ▼';font-size:0.8em}
th.sorted.asc::after{content:' ▲'}
td{padding:10px 12px;border-bottom:1px solid var(--border);transition:background .2s}
tr:hover td{background:rgba(143,180,122,.03)}
tr.new-row td{animation:rowFlash .8s ease}
@keyframes rowFlash{0%{background:rgba(143,180,122,.1)}100%{background:transparent}}
.sk{color:var(--green);font-weight:600}.sd{color:var(--accent)}.sc{color:var(--red);font-weight:600}
.hash{font-family:var(--mono);color:var(--blue)}.mv{font-family:var(--mono);font-weight:500}
.dp{color:var(--red);font-family:var(--mono)}.dn{color:var(--green);font-family:var(--mono)}

/* Filter */
.filter-bar{display:flex;gap:6px;margin-bottom:16px}
.filter-btn{font-family:var(--mono);font-size:0.65em;padding:4px 12px;background:transparent;border:1px solid var(--border);color:var(--dim);cursor:pointer;letter-spacing:2px;transition:all .2s}
.filter-btn:hover{border-color:var(--accent);color:var(--accent)}
.filter-btn.active{background:var(--accent);color:var(--bg);border-color:var(--accent)}

/* Progress bar */
.progress{height:3px;background:var(--border);margin-top:12px;overflow:hidden}
.progress-fill{height:100%;transition:width 1s ease}

@media(max-width:768px){.stats{grid-template-columns:repeat(3,1fr)}.header{flex-direction:column;align-items:flex-start;gap:12px}.content{padding:0 24px 24px}.header{padding:24px}}
</style>
</head>
<body>

<div class="header">
  <div>
    <h1>Auto<em>research</em></h1>
    <div class="header-meta" id="meta"></div>
  </div>
  <div class="header-right">
    <div class="live-badge"><span class="live-dot"></span>LIVE</div>
    <div class="header-meta" id="last-update"></div>
    <button class="refresh-btn" onclick="location.reload()">REFRESH (F5)</button>
  </div>
</div>

<div class="content">
  <div class="stats">
    <div class="stat"><div class="n" id="st">0</div><div class="l">TOTAL</div><div class="progress"><div class="progress-fill" id="pb-total" style="width:100%;background:var(--blue)"></div></div></div>
    <div class="stat k"><div class="n" id="sk">0</div><div class="l">KEEP</div><div class="progress"><div class="progress-fill" id="pb-keep" style="width:0;background:var(--green)"></div></div></div>
    <div class="stat d"><div class="n" id="sd">0</div><div class="l">DISCARD</div><div class="progress"><div class="progress-fill" id="pb-disc" style="width:0;background:var(--accent)"></div></div></div>
    <div class="stat c"><div class="n" id="sc">0</div><div class="l">CRASH</div><div class="progress"><div class="progress-fill" id="pb-crash" style="width:0;background:var(--red)"></div></div></div>
    <div class="stat"><div class="n" id="sb">&mdash;</div><div class="l">BEST</div></div>
    <div class="stat"><div class="n" id="sr">0%</div><div class="l">RATE</div><div class="progress"><div class="progress-fill" id="pb-rate" style="width:0;background:var(--green)"></div></div></div>
  </div>

  <div class="sect">
    <div class="sect-label">METRIC TREND</div>
    <div class="chart-container">
      <canvas id="chart"></canvas>
      <div class="chart-tooltip" id="tooltip"></div>
    </div>
    <div class="chart-legend">
      <span class="legend-keep">keep</span>
      <span class="legend-discard">discard</span>
      <span class="legend-crash">crash</span>
    </div>
  </div>

  <div class="sect">
    <div class="sect-label">EXPERIMENT LOG</div>
    <div class="filter-bar">
      <button class="filter-btn active" data-f="all">ALL</button>
      <button class="filter-btn" data-f="keep">KEEP</button>
      <button class="filter-btn" data-f="discard">DISCARD</button>
      <button class="filter-btn" data-f="crash">CRASH</button>
    </div>
    <div style="overflow-x:auto;max-height:500px;overflow-y:auto">
      <table><thead><tr>
        <th data-col="idx">#</th><th data-col="time">TIME</th><th data-col="commit">COMMIT</th>
        <th data-col="status">STATUS</th><th data-col="metric">METRIC</th><th data-col="value">VALUE</th>
        <th data-col="delta">DELTA</th><th data-col="mem">MEM</th><th data-col="desc">DESCRIPTION</th>
      </tr></thead><tbody id="tb"></tbody></table>
    </div>
  </div>
</div>

<script>
const DATA = __DATA_PLACEHOLDER__;
const FILE_PATH = '__FILE_PATH__';
let currentFilter = 'all';
let sortCol = null, sortAsc = true;

// Stats
const t=DATA.length, k=DATA.filter(e=>e.status==='keep').length, d=DATA.filter(e=>e.status==='discard').length, cr=DATA.filter(e=>e.status==='crash').length;
const vs=DATA.filter(e=>e.status==='keep'&&e.value>0).map(e=>e.value);
const best=vs.length?Math.min(...vs):null;
document.getElementById('st').textContent=t;
document.getElementById('sk').textContent=k;
document.getElementById('sd').textContent=d;
document.getElementById('sc').textContent=cr;
document.getElementById('sb').textContent=best!==null?best.toFixed(4):'\u2014';
document.getElementById('sr').textContent=t?Math.round(k/t*100)+'%':'0%';
document.getElementById('meta').textContent=t+' experiments \u00B7 '+FILE_PATH;
document.getElementById('last-update').textContent='Updated: '+new Date().toLocaleTimeString();

// Progress bars
if(t>0){
  document.getElementById('pb-keep').style.width=Math.round(k/t*100)+'%';
  document.getElementById('pb-disc').style.width=Math.round(d/t*100)+'%';
  document.getElementById('pb-crash').style.width=Math.round(cr/t*100)+'%';
  document.getElementById('pb-rate').style.width=Math.round(k/t*100)+'%';
}

// Chart with hover tooltip
function renderChart(){
  const canvas=document.getElementById('chart'),ctx=canvas.getContext('2d'),tooltip=document.getElementById('tooltip');
  const rect=canvas.parentElement.getBoundingClientRect();
  canvas.width=rect.width*2;canvas.height=(rect.height-48)*2;
  ctx.scale(2,2);const w=rect.width,h=rect.height-48;
  const dd=DATA.filter(e=>e.value>0);if(!dd.length)return;
  const values=dd.map(e=>e.value),mn=Math.min(...values)*.998,mx=Math.max(...values)*1.002,rg=mx-mn||1;
  const px=i=>56+(w-76)*(i/Math.max(dd.length-1,1)),py=v=>16+(h-32)*(1-(v-mn)/rg);

  ctx.clearRect(0,0,w,h);

  // Grid
  ctx.strokeStyle='#1a1d23';ctx.lineWidth=.5;
  for(let i=0;i<=5;i++){const y=16+(h-32)*(i/5);ctx.beginPath();ctx.moveTo(56,y);ctx.lineTo(w-20,y);ctx.stroke();
  ctx.fillStyle='#545b67';ctx.font='9px JetBrains Mono';ctx.textAlign='right';ctx.fillText((mx-rg*i/5).toFixed(4),50,y+3)}

  // Area fill
  ctx.beginPath();ctx.moveTo(px(0),h-16);
  dd.forEach((e,i)=>ctx.lineTo(px(i),py(e.value)));
  ctx.lineTo(px(dd.length-1),h-16);ctx.closePath();
  const grad=ctx.createLinearGradient(0,0,0,h);
  grad.addColorStop(0,'rgba(124,156,186,0.12)');grad.addColorStop(1,'rgba(124,156,186,0)');
  ctx.fillStyle=grad;ctx.fill();

  // Line
  ctx.beginPath();ctx.strokeStyle='#7c9cba';ctx.lineWidth=1.5;
  dd.forEach((e,i)=>{i===0?ctx.moveTo(px(i),py(e.value)):ctx.lineTo(px(i),py(e.value))});ctx.stroke();

  // Points
  const points=[];
  dd.forEach((e,i)=>{
    const x=px(i),y=py(e.value);
    ctx.beginPath();ctx.arc(x,y,4,0,Math.PI*2);
    ctx.fillStyle=e.status==='keep'?'#8fb47a':e.status==='discard'?'#c8956c':'#c75c5c';
    ctx.fill();ctx.strokeStyle='#08090c';ctx.lineWidth=1.5;ctx.stroke();
    points.push({x,y,data:e,idx:i});
  });

  // Hover
  canvas.onmousemove=function(ev){
    const br=canvas.getBoundingClientRect();
    const mx2=(ev.clientX-br.left),my2=(ev.clientY-br.top);
    let closest=null,minDist=30;
    points.forEach(p=>{const dist=Math.hypot(p.x-mx2,p.y-my2);if(dist<minDist){minDist=dist;closest=p}});
    if(closest){
      const e=closest.data;
      const statusColor=e.status==='keep'?'var(--green)':e.status==='discard'?'var(--accent)':'var(--red)';
      tooltip.style.opacity='1';
      tooltip.style.left=Math.min(closest.x+12,w-200)+'px';
      tooltip.style.top=(closest.y-80)+'px';
      const ttStatus=document.createElement('div');ttStatus.className='tt-status';ttStatus.style.color=statusColor;ttStatus.textContent=e.status.toUpperCase()+' #'+(closest.idx+1);
      const rows=[['value',e.value.toFixed(6)],['delta',e.delta!=null?(e.delta>0?'+':'')+e.delta.toFixed(4):'\u2014'],['commit',e.commit.substring(0,7)],['desc',e.description]];
      tooltip.textContent='';tooltip.appendChild(ttStatus);
      rows.forEach(r=>{const row=document.createElement('div');row.className='tt-row';
        const l=document.createElement('span');l.textContent=r[0];
        const v=document.createElement('span');v.className='tt-val';v.textContent=r[1];
        row.appendChild(l);row.appendChild(v);tooltip.appendChild(row)});
    } else {tooltip.style.opacity='0'}
  };
  canvas.onmouseleave=()=>{tooltip.style.opacity='0'};
}
renderChart();
window.addEventListener('resize',renderChart);

// Table
function renderTable(){
  const filtered=currentFilter==='all'?DATA:DATA.filter(e=>e.status===currentFilter);
  const sorted=sortCol?[...filtered].sort((a,b)=>{
    let va=a[sortCol],vb=b[sortCol];
    if(typeof va==='number'&&typeof vb==='number')return sortAsc?va-vb:vb-va;
    return sortAsc?String(va).localeCompare(String(vb)):String(vb).localeCompare(String(va));
  }):filtered;
  const tb=document.getElementById('tb');tb.textContent='';
  sorted.forEach((e,i)=>{
    const tr=document.createElement('tr');
    const globalIdx=DATA.indexOf(e)+1;
    [{v:globalIdx,s:'font-family:var(--mono);color:var(--dim)'},{v:e.time?e.time.substring(11,19):'\u2014',s:'font-family:var(--mono);color:var(--dim);font-size:.9em'},{v:(e.commit||'').substring(0,7),c:'hash'},{v:e.status,c:e.status==='keep'?'sk':e.status==='discard'?'sd':'sc'},{v:e.metric,s:'font-family:var(--mono);font-size:.9em'},{v:e.value>0?e.value.toFixed(6):'\u2014',c:'mv'},{v:e.delta!=null?(e.delta>0?'+':'')+e.delta.toFixed(4):'\u2014',c:e.delta!=null?(e.delta<0?'dn':'dp'):''},{v:e.memory_gb!=null?e.memory_gb.toFixed(1)+'G':'\u2014',s:'font-family:var(--mono);font-size:.85em;color:var(--dim)'},{v:e.description,s:'color:var(--dim);font-size:.9em;max-width:300px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap'}].forEach(x=>{const td=document.createElement('td');td.textContent=x.v;if(x.c)td.className=x.c;if(x.s)td.setAttribute('style',x.s);tr.appendChild(td)});
    tb.appendChild(tr)});
}
renderTable();

// Filter buttons
document.querySelectorAll('.filter-btn').forEach(btn=>{
  btn.addEventListener('click',()=>{
    document.querySelectorAll('.filter-btn').forEach(b=>b.classList.remove('active'));
    btn.classList.add('active');
    currentFilter=btn.dataset.f;
    renderTable();
  });
});

// Sort headers
document.querySelectorAll('th[data-col]').forEach(th=>{
  th.addEventListener('click',()=>{
    const col=th.dataset.col;
    const colMap={idx:'',time:'time',commit:'commit',status:'status',metric:'metric',value:'value',delta:'delta',mem:'memory_gb',desc:'description'};
    const mapped=colMap[col];if(!mapped)return;
    if(sortCol===mapped){sortAsc=!sortAsc}else{sortCol=mapped;sortAsc=true}
    document.querySelectorAll('th').forEach(t=>{t.classList.remove('sorted','asc')});
    th.classList.add('sorted');if(sortAsc)th.classList.add('asc');
    renderTable();
  });
});

// Keyboard shortcut
document.addEventListener('keydown',e=>{if(e.key==='F5'||e.key==='r'&&(e.metaKey||e.ctrlKey)){e.preventDefault();location.reload()}});
</script>
</body>
</html>
HTMLEOF

# DATA + FILE_PATH 주입
python3 -c "
html = open('$OUT').read()
html = html.replace('__DATA_PLACEHOLDER__', '''$DATA''')
html = html.replace('__FILE_PATH__', '$JSONL_ABS')
open('$OUT', 'w').write(html)
"

echo "대시보드 생성: $OUT"
open "$OUT"
