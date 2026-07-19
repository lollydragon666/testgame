const COLS = 10;
const ROWS = 20;
const BLOCK = 24;
const SCORE_TABLE = [0, 100, 300, 500, 800];
const ATTACK_TABLE = [0, 0, 1, 2, 4];
const COLORS = { I:'#c49a57', J:'#627084', L:'#b65f31', O:'#d0b46b', S:'#70814f', T:'#795b78', Z:'#9e3037', G:'#4f4940' };
const SHAPES = {
  I:[[0,0,0,0],[1,1,1,1],[0,0,0,0],[0,0,0,0]], J:[[1,0,0],[1,1,1],[0,0,0]],
  L:[[0,0,1],[1,1,1],[0,0,0]], O:[[1,1],[1,1]], S:[[0,1,1],[1,1,0],[0,0,0]],
  T:[[0,1,0],[1,1,1],[0,0,0]], Z:[[1,1,0],[0,1,1],[0,0,0]]
};

const $ = id => document.getElementById(id);
const ui = {
  menu:$('menuScreen'), game:$('gameScreen'), arena:$('arena'), station2:$('station2'), versus:$('versusMark'),
  p2Field:$('player2Field'), networkPanel:$('networkPanel'), networkStatus:$('networkStatus'), note:$('modeNote'), leaderboard:$('leaderboardBody'), replays:$('replayList'), modal:$('gameModal'),
  modalKicker:$('modalKicker'), modalTitle:$('modalTitle'), modalText:$('modalText'), status:$('matchStatus'),
  modeLabel:$('gameModeLabel'), pause:$('pauseButton'), sound:$('soundButton'), replayProgress:$('replayProgress'), replayBar:$('replayProgressBar')
};

let selectedMode = 'solo';
let games = [];
let running = false;
let paused = false;
let raf = 0;
let lastTime = 0;
let soundOn = true;
let audioContext = null;
let activeRecording = null;
let replayMode = false;
let replayData = null;
let replayIndex = 0;
let replayStart = 0;
let replayPauseStarted = 0;
let replayFxSerials = [];
let network = {room:'',playerId:'',slot:0,started:false,syncing:false,timer:0,outAttack:0,lastAttack:0,opponentId:'',ended:false};

function tone(frequency, duration=.05, volume=.025, delay=0) {
  if (!soundOn) return;
  try {
    audioContext ||= new (window.AudioContext || window.webkitAudioContext)();
    const osc = audioContext.createOscillator();
    const gain = audioContext.createGain();
    osc.type = 'square'; osc.frequency.value = frequency;
    gain.gain.setValueAtTime(volume, audioContext.currentTime + delay);
    gain.gain.exponentialRampToValueAtTime(.001, audioContext.currentTime + delay + duration);
    osc.connect(gain).connect(audioContext.destination);
    osc.start(audioContext.currentTime + delay); osc.stop(audioContext.currentTime + delay + duration);
  } catch (_) { /* Sound is optional. */ }
}

class TetrisGame {
  constructor(index, name) {
    this.index = index;
    this.name = name;
    this.canvas = $(`board${index}`);
    this.ctx = this.canvas.getContext('2d');
    this.nextCanvas = $(`next${index}`);
    this.nextCtx = this.nextCanvas.getContext('2d');
    this.frame = $(`frame${index}`);
    this.effect = $(`effect${index}`);
    this.bag = [];
    this.reset();
  }

  reset() {
    this.board = Array.from({length:ROWS}, () => Array(COLS).fill(null));
    this.score = 0; this.lines = 0; this.level = 1; this.dropCounter = 0; this.alive = true; this.particles = []; this.version = 0; this.fxSerial = 0;
    this.nextPiece = this.randomPiece();
    this.spawn(); this.updateStats(); this.drawNext(); this.draw();
  }

  refillBag() {
    this.bag = Object.keys(SHAPES);
    for (let i=this.bag.length-1;i>0;i--) { const j=Math.floor(Math.random()*(i+1)); [this.bag[i],this.bag[j]]=[this.bag[j],this.bag[i]]; }
  }

  randomPiece() {
    if (!this.bag.length) this.refillBag();
    const type = this.bag.pop();
    return {type, matrix:SHAPES[type].map(row=>[...row]), x:0, y:0};
  }

  spawn() {
    this.piece = this.nextPiece;
    this.nextPiece = this.randomPiece();
    this.piece.x = Math.floor((COLS-this.piece.matrix[0].length)/2);
    this.piece.y = this.piece.type === 'I' ? -1 : 0;
    this.drawNext();
    this.version++;
    if (this.collides(this.piece)) this.lose();
  }

  collides(test, dx=0, dy=0, matrix=test.matrix) {
    return matrix.some((row,y)=>row.some((value,x)=>{
      if (!value) return false;
      const bx=test.x+x+dx, by=test.y+y+dy;
      return bx<0 || bx>=COLS || by>=ROWS || (by>=0 && this.board[by][bx]);
    }));
  }

  move(dx) {
    if (!this.active()) return;
    if (!this.collides(this.piece,dx)) { this.piece.x+=dx; this.version++; tone(170,.02,.012); }
  }

  rotate() {
    if (!this.active() || this.piece.type==='O') return;
    const rotated=this.piece.matrix[0].map((_,i)=>this.piece.matrix.map(row=>row[i]).reverse());
    for (const kick of [0,-1,1,-2,2]) if (!this.collides(this.piece,kick,0,rotated)) { this.piece.x+=kick; this.piece.matrix=rotated; this.version++; tone(310,.035,.018); return; }
  }

  softDrop(manual=false) {
    if (!this.active()) return;
    if (!this.collides(this.piece,0,1)) { this.piece.y++; if (manual) this.score++; }
    else this.lock();
    this.dropCounter=0; this.version++; this.updateStats();
  }

  hardDrop() {
    if (!this.active()) return;
    let distance=0;
    while (!this.collides(this.piece,0,1)) { this.piece.y++; distance++; }
    this.score+=distance*2; tone(250,.06,.03); this.lock(); this.version++; this.updateStats();
  }

  lock() {
    this.piece.matrix.forEach((row,y)=>row.forEach((value,x)=>{ if(value && this.piece.y+y>=0) this.board[this.piece.y+y][this.piece.x+x]=this.piece.type; }));
    const cleared=this.clearLines();
    if (cleared) onLinesCleared(this,cleared);
    if (this.alive) this.spawn();
  }

  clearLines() {
    let cleared=0;
    for (let y=ROWS-1;y>=0;y--) if (this.board[y].every(Boolean)) { this.board.splice(y,1); this.board.unshift(Array(COLS).fill(null)); cleared++; y++; }
    if (cleared) {
      this.score+=SCORE_TABLE[cleared]*this.level; this.lines+=cleared; this.level=Math.floor(this.lines/10)+1; this.updateStats();
      tone(cleared===4?760:480,.11,.035);
    }
    return cleared;
  }

  addGarbage(amount) {
    if (!this.alive || !amount) return;
    let overflow=false;
    for (let i=0;i<amount;i++) {
      if (this.board.shift().some(Boolean)) overflow=true;
      const hole=Math.floor(Math.random()*COLS);
      this.board.push(Array.from({length:COLS},(_,x)=>x===hole?null:'G'));
    }
    this.frame.classList.add('shake'); setTimeout(()=>this.frame.classList.remove('shake'),470);
    this.version++;
    tone(95,.14,.045);
    if (overflow || this.collides(this.piece)) this.lose();
  }

  tetrisFx() {
    this.fxSerial++; this.version++;
    this.effect.classList.remove('active'); this.frame.classList.remove('shake','flash');
    void this.effect.offsetWidth;
    this.effect.classList.add('active'); this.frame.classList.add('shake','flash');
    setTimeout(()=>{ this.effect.classList.remove('active'); this.frame.classList.remove('shake','flash'); },900);
    for (let i=0;i<55;i++) this.particles.push({x:120,y:250,vx:(Math.random()-.5)*8,vy:(Math.random()-.7)*8,life:1,color:i%2?COLORS.I:COLORS.Z});
    [520,650,780,1040].forEach((f,i)=>tone(f,.18,.035,i*.07));
  }

  lose() { if (!this.alive) return; this.alive=false; onPlayerLost(this); }
  active() { return running && !paused && this.alive; }

  update(delta) {
    if (!this.active()) return;
    this.dropCounter+=delta;
    const interval=Math.max(90,850*Math.pow(.82,this.level-1));
    if (this.dropCounter>interval) this.softDrop();
  }

  ghostY() { let y=this.piece.y; while(!this.collides({...this.piece,y},0,1)) y++; return y; }

  drawCell(context,x,y,color,size=BLOCK,alpha=1) {
    context.save(); context.globalAlpha=alpha; context.fillStyle=color; context.fillRect(x*size+2,y*size+2,size-4,size-4);
    context.fillStyle='rgba(255,255,255,.27)'; context.fillRect(x*size+4,y*size+4,size-8,2);
    context.fillStyle='rgba(0,0,0,.25)'; context.fillRect(x*size+4,(y+1)*size-6,size-8,2); context.restore();
  }

  drawMatrix(context,matrix,ox,oy,type,size=BLOCK,alpha=1) {
    matrix.forEach((row,y)=>row.forEach((value,x)=>{ if(value && oy+y>=0) this.drawCell(context,ox+x,oy+y,COLORS[type],size,alpha); }));
  }

  draw() {
    const c=this.ctx; c.fillStyle='#090806'; c.fillRect(0,0,240,480); c.strokeStyle='rgba(129,101,67,.16)'; c.lineWidth=1;
    for(let x=0;x<=COLS;x++){c.beginPath();c.moveTo(x*BLOCK,0);c.lineTo(x*BLOCK,480);c.stroke();}
    for(let y=0;y<=ROWS;y++){c.beginPath();c.moveTo(0,y*BLOCK);c.lineTo(240,y*BLOCK);c.stroke();}
    this.board.forEach((row,y)=>row.forEach((type,x)=>{if(type)this.drawCell(c,x,y,COLORS[type]);}));
    if(this.piece&&this.alive){this.drawMatrix(c,this.piece.matrix,this.piece.x,this.ghostY(),this.piece.type,BLOCK,.14);this.drawMatrix(c,this.piece.matrix,this.piece.x,this.piece.y,this.piece.type);}
    this.particles=this.particles.filter(p=>p.life>0);
    this.particles.forEach(p=>{p.x+=p.vx;p.y+=p.vy;p.vy+=.2;p.life-=.025;c.globalAlpha=Math.max(0,p.life);c.fillStyle=p.color;c.fillRect(p.x,p.y,4,4);}); c.globalAlpha=1;
  }

  drawNext() {
    const c=this.nextCtx,size=18,m=this.nextPiece.matrix; c.clearRect(0,0,96,80);
    this.drawMatrix(c,m,(96/size-m[0].length)/2,(80/size-m.length)/2,this.nextPiece.type,size);
  }

  updateStats() {
    $(`score${this.index}`).textContent=String(this.score).padStart(6,'0');
    $(`lines${this.index}`).textContent=this.lines; $(`level${this.index}`).textContent=this.level;
  }
}

function cleanName(value,fallback) { return value.trim().replace(/[<>]/g,'').slice(0,14).toUpperCase() || fallback; }

function packGame(game) {
  return {
    b:game.board.map(row=>row.map(cell=>cell||'.').join('')),
    p:{t:game.piece.type,x:game.piece.x,y:game.piece.y,m:game.piece.matrix.map(row=>row.join(''))},
    n:game.nextPiece.type,s:game.score,l:game.lines,v:game.level,a:game.alive,f:game.fxSerial
  };
}

function beginRecording(names) {
  activeRecording={id:`${Date.now()}-${Math.random().toString(36).slice(2,7)}`,mode:selectedMode,names,date:Date.now(),started:performance.now(),duration:0,result:'',frames:[],signature:''};
  recordFrame(true);
}

function recordFrame(force=false) {
  if(!activeRecording||replayMode)return;
  const signature=games.map(game=>game.version).join(':');
  if(!force&&signature===activeRecording.signature)return;
  activeRecording.signature=signature;
  if(activeRecording.frames.length>=2500)return;
  activeRecording.frames.push({t:Math.round(performance.now()-activeRecording.started),players:games.map(packGame)});
}

function getReplays() { try{return JSON.parse(localStorage.getItem('neonBlocksReplays')||'[]');}catch(_){return [];} }

function finishRecording(result) {
  if(!activeRecording)return;
  recordFrame(true);
  activeRecording.duration=Math.max(1,Math.round(performance.now()-activeRecording.started));
  activeRecording.result=result;
  const replay={...activeRecording}; delete replay.started; delete replay.signature;
  const saved=getReplays(); saved.unshift(replay);
  while(saved.length>5)saved.pop();
  while(saved.length) {
    try { localStorage.setItem('neonBlocksReplays',JSON.stringify(saved)); break; }
    catch(_) { saved.pop(); }
  }
  activeRecording=null; renderReplays();
}

function applyReplayFrame(frame) {
  frame.players.forEach((state,index)=>{
    const game=games[index]; if(!game)return;
    game.board=state.b.map(row=>[...row].map(cell=>cell==='.'?null:cell));
    game.piece={type:state.p.t,x:state.p.x,y:state.p.y,matrix:state.p.m.map(row=>[...row].map(Number))};
    game.nextPiece={type:state.n,matrix:SHAPES[state.n].map(row=>[...row]),x:0,y:0};
    game.score=state.s; game.lines=state.l; game.level=state.v; game.alive=state.a;
    if(state.f>replayFxSerials[index])game.tetrisFx();
    replayFxSerials[index]=state.f; game.updateStats(); game.drawNext(); game.draw();
  });
}

function startReplay(id) {
  const replay=getReplays().find(item=>item.id===id); if(!replay||!replay.frames.length)return;
  running=false; cancelAnimationFrame(raf); activeRecording=null; replayMode=true; replayData=replay; replayIndex=0; paused=false; replayFxSerials=replay.names.map(()=>0);
  selectedMode=replay.mode; games=replay.names.map((name,index)=>new TetrisGame(index+1,name));
  replay.names.forEach((name,index)=>$(`player${index+1}Label`).textContent=name);
  ui.station2.classList.toggle('hidden',replay.mode==='solo'); ui.versus.classList.toggle('hidden',replay.mode==='solo'); ui.arena.classList.toggle('solo',replay.mode==='solo');
  ui.menu.classList.add('hidden'); ui.game.classList.remove('hidden'); ui.modal.classList.add('hidden'); ui.replayProgress.classList.remove('hidden');
  ui.modeLabel.textContent=`РЕПЛЕЙ · ${replay.mode==='solo'?'СОЛО':replay.mode==='network'?'СЕТЬ':'ДУЭЛЬ'}`; ui.pause.classList.remove('hidden'); ui.pause.textContent='Ⅱ ПАУЗА';
  applyReplayFrame(replay.frames[0]); replayStart=performance.now(); replayStartLoop();
}

function replayStartLoop() { cancelAnimationFrame(raf); raf=requestAnimationFrame(replayLoop); }

function replayLoop(time) {
  if(!replayMode||paused)return;
  const elapsed=time-replayStart;
  while(replayIndex+1<replayData.frames.length&&replayData.frames[replayIndex+1].t<=elapsed) { replayIndex++; applyReplayFrame(replayData.frames[replayIndex]); }
  const progress=Math.min(1,elapsed/replayData.duration); ui.replayBar.style.width=`${progress*100}%`; ui.status.textContent=`${formatTime(elapsed)} / ${formatTime(replayData.duration)}`;
  if(progress>=1) {
    paused=true; ui.pause.textContent='↻ СНАЧАЛА'; $('rematchButton').textContent='СНАЧАЛА';
    showResult('РЕПЛЕЙ ЗАВЕРШЁН',replayData.result||'Запись матча воспроизведена полностью.','КОНЕЦ ЗАПИСИ');
  } else raf=requestAnimationFrame(replayLoop);
}

function toggleReplayPause() {
  if(!replayMode)return;
  if(paused&&replayIndex>=replayData.frames.length-1){startReplay(replayData.id);return;}
  paused=!paused;
  if(paused){replayPauseStarted=performance.now();ui.pause.textContent='▶ ПРОДОЛЖИТЬ';}
  else {replayStart+=performance.now()-replayPauseStarted;ui.pause.textContent='Ⅱ ПАУЗА';replayStartLoop();}
}

function formatTime(milliseconds) {
  const seconds=Math.max(0,Math.floor(milliseconds/1000)); return `${String(Math.floor(seconds/60)).padStart(2,'0')}:${String(seconds%60).padStart(2,'0')}`;
}

function escapeHtml(value) { return String(value).replace(/[&<>'"]/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[char])); }

function renderReplays() {
  const replays=getReplays();
  if(!replays.length){ui.replays.innerHTML='<div class="replay-empty">Записи появятся после первого матча</div>';return;}
  ui.replays.innerHTML=replays.map(replay=>`<div class="replay-item"><div class="replay-meta"><strong>${escapeHtml(replay.names.join(' vs '))}</strong><span>${replay.mode==='solo'?'СОЛО':replay.mode==='network'?'СЕТЬ':'ДУЭЛЬ'} · ${formatTime(replay.duration)} · ${replay.frames.length} кадров</span></div><div class="replay-actions"><button class="replay-play" type="button" data-replay-id="${replay.id}">▶ СМОТРЕТЬ</button><button class="replay-delete" type="button" data-delete-replay="${replay.id}" aria-label="Удалить реплей">×</button></div></div>`).join('');
}

function setNetworkStatus(title,text,type='') {
  ui.networkStatus.className=`network-status ${type}`.trim();
  ui.networkStatus.querySelector('p').innerHTML=`<strong>${escapeHtml(title)}</strong>${escapeHtml(text)}`;
}

async function networkRequest(path,data) {
  if(location.protocol==='file:')throw new Error('Игра открыта как файл. Запустите start-server.cmd и используйте адрес http://127.0.0.1:4173');
  let response;
  try { response=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}); }
  catch(_) { throw new Error('Сервер недоступен. Запустите start-server.cmd и обновите страницу.'); }
  let result;
  try { result=await response.json(); }
  catch(_) { throw new Error('Открыт сервер без сетевого режима. Перезапустите start-server.cmd.'); }
  if(!response.ok||!result.ok)throw new Error(result.error||'Сервер недоступен');
  return result;
}

function resetNetwork() {
  clearInterval(network.timer);
  network={room:'',playerId:'',slot:0,started:false,syncing:false,timer:0,outAttack:0,lastAttack:0,opponentId:'',ended:false};
}

async function createNetworkRoom() {
  try {
    resetNetwork(); setNetworkStatus('СОЗДАЁМ КОМНАТУ','Обращаемся к хранителю сети…','waiting');
    const name=cleanName($('player1Name').value,'PLAYER 1'); $('player1Name').value=name;
    const result=await networkRequest('/api/create',{name});
    network.room=result.code; network.playerId=result.playerId; network.slot=result.slot;
    $('roomCodeInput').value=result.code; setNetworkStatus(`КОМНАТА ${result.code}`,'Передайте этот код другу. Ожидаем второго игрока…','waiting');
    network.timer=setInterval(networkTick,180); networkTick();
  } catch(error) { setNetworkStatus('НЕ УДАЛОСЬ СОЗДАТЬ',error.message,'error'); }
}

async function joinNetworkRoom() {
  try {
    resetNetwork();
    const code=$('roomCodeInput').value.trim().toUpperCase();
    if(code.length!==4)throw new Error('Введите код из четырёх символов');
    setNetworkStatus('ИЩЕМ КОМНАТУ',`Пробуем войти в ${code}…`,'waiting');
    const name=cleanName($('player1Name').value,'PLAYER 2'); $('player1Name').value=name;
    const result=await networkRequest('/api/join',{code,name});
    network.room=result.code; network.playerId=result.playerId; network.slot=result.slot;
    setNetworkStatus(`КОМНАТА ${result.code}`,'Соединение установлено. Начинаем поединок…','waiting');
    network.timer=setInterval(networkTick,180); await networkTick();
  } catch(error) { setNetworkStatus('НЕ УДАЛОСЬ ВОЙТИ',error.message,'error'); }
}

async function networkTick() {
  if(network.syncing||!network.room||!network.playerId)return;
  network.syncing=true;
  try {
    const state=network.started&&games[0]?packGame(games[0]):null;
    const result=await networkRequest('/api/sync',{code:network.room,playerId:network.playerId,state,attack:network.outAttack});
    if(!network.started&&result.players.length===2)startNetworkMatch(result.players);
    if(network.started) {
      const opponent=result.players.find(player=>player.id!==network.playerId);
      if(opponent) {
        network.opponentId=opponent.id;
        if(opponent.state)applyNetworkOpponentState(opponent.state);
        const incoming=Math.max(0,(opponent.attack||0)-network.lastAttack); network.lastAttack=opponent.attack||0;
        if(incoming&&games[0]?.alive)games[0].addGarbage(incoming);
        if(opponent.state&&opponent.state.a===false&&!network.ended)finishNetworkMatch(true);
      }
    }
  } catch(error) {
    if(!network.ended)setNetworkStatus('СВЯЗЬ ПОТЕРЯНА',error.message,'error');
  } finally { network.syncing=false; }
}

function startNetworkMatch(players) {
  const me=players.find(player=>player.id===network.playerId);
  const opponent=players.find(player=>player.id!==network.playerId);
  if(!me||!opponent)return;
  network.started=true; network.opponentId=opponent.id; network.lastAttack=opponent.attack||0; network.ended=false;
  selectedMode='network'; games=[new TetrisGame(1,me.name),new TetrisGame(2,opponent.name)]; games[1].alive=true;
  $('player1Label').textContent=me.name; $('player2Label').textContent=opponent.name;
  ui.station2.classList.remove('hidden'); ui.versus.classList.remove('hidden'); ui.arena.classList.remove('solo');
  ui.menu.classList.add('hidden'); ui.game.classList.remove('hidden'); ui.modal.classList.add('hidden'); ui.replayProgress.classList.add('hidden');
  ui.modeLabel.textContent=`СЕТЕВОЙ ПОЕДИНОК · ${network.room}`; ui.status.textContent='СВЯЗЬ УСТАНОВЛЕНА'; ui.pause.textContent='Ⅱ ПАУЗА';
  ui.pause.classList.add('hidden');
  running=true; paused=false; replayMode=false; lastTime=performance.now(); beginRecording(games.map(game=>game.name)); cancelAnimationFrame(raf); raf=requestAnimationFrame(loop); tone(520,.08,.03);
}

function applyNetworkOpponentState(state) {
  const game=games[1]; if(!game)return;
  game.board=state.b.map(row=>[...row].map(cell=>cell==='.'?null:cell));
  game.piece={type:state.p.t,x:state.p.x,y:state.p.y,matrix:state.p.m.map(row=>[...row].map(Number))};
  game.nextPiece={type:state.n,matrix:SHAPES[state.n].map(row=>[...row]),x:0,y:0};
  game.score=state.s; game.lines=state.l; game.level=state.v;
  if(state.f>game.fxSerial)game.tetrisFx(); game.fxSerial=state.f; game.alive=state.a; game.version++;
  game.updateStats(); game.drawNext(); game.draw();
}

function finishNetworkMatch(won) {
  if(network.ended)return;
  network.ended=true; running=false; cancelAnimationFrame(raf); clearInterval(network.timer);
  const local=games[0],opponent=games[1]; recordFrame(true);
  if(won) {
    saveScore(local.name,local.score,'СЕТЬ'); finishRecording(`${local.name} победил ${opponent.name} по локальной сети.`);
    showResult(`${local.name} ПОБЕЖДАЕТ!`,`${opponent.name} пал под натиском проклятых рун.`,'СЕТЕВОЙ ПОЕДИНОК ЗАВЕРШЁН');
  } else {
    finishRecording(`${local.name} проиграл ${opponent.name} по локальной сети.`);
    showResult('ПОРАЖЕНИЕ',`${opponent.name} пережил этот поединок.`,'ВАШЕ ПОЛЕ ПАЛО');
  }
  renderLeaderboard();
}

function selectMode(mode) {
  if(selectedMode==='network'&&mode!=='network')resetNetwork();
  selectedMode=mode;
  document.querySelectorAll('.mode-tab').forEach(button=>button.classList.toggle('active',button.dataset.mode===mode));
  ui.p2Field.classList.toggle('hidden',mode!=='versus');
  ui.networkPanel.classList.toggle('hidden',mode!=='network'); $('startButton').classList.toggle('hidden',mode==='network');
  ui.note.innerHTML=mode==='solo'
    ? '<span>✦</span><p><strong>ОДИНОКОЕ ИСПЫТАНИЕ</strong>Разрушай рунические ряды и впиши своё имя в книгу славы.</p>'
    : mode==='versus'
      ? '<span>☩</span><p><strong>КРОВАВЫЙ ПОЕДИНОК</strong>2, 3 или 4 ряда насылают сопернику 1, 2 или 4 проклятых строки.</p>'
      : '<span>⌘</span><p><strong>ПО ЛОКАЛЬНОЙ СЕТИ</strong>Создайте комнату и передайте другу адрес сервера и четырёхзначный код.</p>';
  ui.note.style.borderColor=mode==='versus'?'var(--pink)':mode==='network'?'#71805a':'var(--cyan)';
  if(mode==='network'&&location.protocol==='file:')setNetworkStatus('НУЖЕН ЛОКАЛЬНЫЙ СЕРВЕР','Закройте эту вкладку, запустите start-server.cmd и откройте адрес http://127.0.0.1:4173.','error');
}

function startMatch() {
  if(selectedMode==='network')return;
  const name1=cleanName($('player1Name').value,'PLAYER 1');
  const name2=cleanName($('player2Name').value,'PLAYER 2');
  $('player1Name').value=name1; $('player2Name').value=name2; $('player1Label').textContent=name1; $('player2Label').textContent=name2;
  games=[new TetrisGame(1,name1)];
  if(selectedMode==='versus') games.push(new TetrisGame(2,name2));
  replayMode=false; replayData=null; ui.replayProgress.classList.add('hidden'); ui.replayBar.style.width='0';
  ui.station2.classList.toggle('hidden',selectedMode!=='versus'); ui.versus.classList.toggle('hidden',selectedMode!=='versus'); ui.arena.classList.toggle('solo',selectedMode==='solo');
  ui.modeLabel.textContent=selectedMode==='solo'?'ОДИНОКОЕ ИСПЫТАНИЕ':'КРОВАВЫЙ ПОЕДИНОК'; ui.status.textContent=selectedMode==='solo'?'ГЛУБИНА 1':'ВЫЖИВЕТ ТОЛЬКО ОДИН';
  ui.menu.classList.add('hidden'); ui.game.classList.remove('hidden'); ui.modal.classList.add('hidden');
  running=true; paused=false; ui.pause.classList.remove('hidden'); ui.pause.textContent='Ⅱ ПАУЗА'; lastTime=performance.now(); beginRecording(games.map(game=>game.name)); cancelAnimationFrame(raf); raf=requestAnimationFrame(loop); tone(520,.08,.03);
}

function loop(time) {
  const delta=Math.min(time-lastTime,100); lastTime=time;
  if(running&&!paused){
    if(selectedMode==='network'){games[0]?.update(delta);games.forEach(game=>game.draw());}
    else games.forEach(game=>{game.update(delta);game.draw();});
    recordFrame(); if(selectedMode==='solo'&&games[0])ui.status.textContent=`ГЛУБИНА ${games[0].level}`; raf=requestAnimationFrame(loop);
  }
}

function onLinesCleared(game,cleared) {
  if(cleared===4) game.tetrisFx();
  if(selectedMode==='versus') { const opponent=games.find(item=>item!==game); opponent?.addGarbage(ATTACK_TABLE[cleared]); }
  if(selectedMode==='network'&&game===games[0])network.outAttack+=ATTACK_TABLE[cleared];
}

function onPlayerLost(loser) {
  if(!running)return;
  if(selectedMode==='network') {
    if(loser===games[0]) { networkTick(); setTimeout(networkTick,180); setTimeout(()=>finishNetworkMatch(false),650); }
    return;
  }
  running=false; cancelAnimationFrame(raf);
  $('rematchButton').textContent='ЕЩЁ РАЗ';
  if(selectedMode==='versus') {
    const winner=games.find(game=>game!==loser); saveScore(winner.name,winner.score,'ДУЭЛЬ');
    const result=`${winner.name} победил ${loser.name}. Счёт: ${winner.score}.`; finishRecording(result);
    showResult(`${winner.name} ПОБЕЖДАЕТ!`,`${loser.name} не смог удержать поле. Счёт победителя: ${winner.score}.`,'ПОБЕДИТЕЛЬ ОПРЕДЕЛЁН');
  } else {
    saveScore(loser.name,loser.score,'СОЛО');
    finishRecording(`${loser.name}: ${loser.score} очков, ${loser.lines} линий.`);
    showResult('ЗАБЕГ ОКОНЧЕН',`${loser.name}, твой результат — ${loser.score}. Очищено линий: ${loser.lines}.`,'РЕЗУЛЬТАТ СОХРАНЁН');
  }
  renderLeaderboard(); tone(110,.34,.06);
}

function showResult(title,text,kicker) { ui.modalTitle.textContent=title; ui.modalText.textContent=text; ui.modalKicker.textContent=kicker; ui.modal.classList.remove('hidden'); }

function togglePause() {
  if(selectedMode==='network')return;
  if(!running)return; paused=!paused; ui.pause.textContent=paused?'▶ ПРОДОЛЖИТЬ':'Ⅱ ПАУЗА';
  if(paused) { $('rematchButton').textContent='ПРОДОЛЖИТЬ'; showResult('ПАУЗА','Матч заморожен. Нажмите ESC или кнопку «Продолжить».','ВРЕМЯ ОСТАНОВЛЕНО'); }
  else {ui.modal.classList.add('hidden');lastTime=performance.now();raf=requestAnimationFrame(loop);}
}

function returnToMenu() {
  if(activeRecording)finishRecording('Матч был остановлен игроком.');
  running=false; paused=false; replayMode=false; replayData=null; resetNetwork(); cancelAnimationFrame(raf); ui.modal.classList.add('hidden'); ui.replayProgress.classList.add('hidden'); ui.game.classList.add('hidden'); ui.menu.classList.remove('hidden'); renderLeaderboard(); renderReplays();
}

function getScores() { try{return JSON.parse(localStorage.getItem('neonBlocksScores')||'[]');}catch(_){return [];} }
function saveScore(name,score,mode) {
  const scores=getScores(); scores.push({name,score,mode,date:Date.now()}); scores.sort((a,b)=>b.score-a.score); localStorage.setItem('neonBlocksScores',JSON.stringify(scores.slice(0,10)));
}
function renderLeaderboard() {
  const scores=getScores();
  if(!scores.length){ui.leaderboard.innerHTML='<tr class="empty-row"><td colspan="4">ПОКА ПУСТО<br>Первый рекорд ждёт своего игрока</td></tr>';return;}
  ui.leaderboard.innerHTML=scores.map((item,i)=>`<tr><td>${String(i+1).padStart(2,'0')}</td><td>${item.name}</td><td>${item.mode}</td><td>${String(item.score).padStart(6,'0')}</td></tr>`).join('');
}

document.querySelectorAll('.mode-tab').forEach(button=>button.addEventListener('click',()=>selectMode(button.dataset.mode)));
$('createRoomButton').addEventListener('click',createNetworkRoom);
$('joinRoomButton').addEventListener('click',joinNetworkRoom);
$('roomCodeInput').addEventListener('input',event=>{event.target.value=event.target.value.toUpperCase().replace(/[^A-Z0-9]/g,'').slice(0,4);});
$('startButton').addEventListener('click',startMatch); $('rematchButton').addEventListener('click',()=>replayMode?startReplay(replayData.id):(paused?togglePause():startMatch()));
$('menuButton').addEventListener('click',returnToMenu); $('modalMenuButton').addEventListener('click',returnToMenu); $('brandButton').addEventListener('click',returnToMenu);
ui.pause.addEventListener('click',()=>replayMode?toggleReplayPause():togglePause());
ui.replays.addEventListener('click',event=>{
  const deleteButton=event.target.closest('[data-delete-replay]');
  if(deleteButton){const filtered=getReplays().filter(replay=>replay.id!==deleteButton.dataset.deleteReplay);localStorage.setItem('neonBlocksReplays',JSON.stringify(filtered));renderReplays();return;}
  const button=event.target.closest('[data-replay-id]'); if(button)startReplay(button.dataset.replayId);
});
ui.sound.addEventListener('click',()=>{soundOn=!soundOn;ui.sound.querySelector('b').textContent=soundOn?'ВКЛ':'ВЫКЛ';if(soundOn)tone(520,.07);});

document.addEventListener('keydown',event=>{
  if(event.code==='Escape'&&replayMode){event.preventDefault();toggleReplayPause();return;}
  if(event.code==='Escape'&&running){event.preventDefault();togglePause();return;}
  if(!running||paused)return;
  const controls={
    KeyA:()=>games[0]?.move(-1),KeyD:()=>games[0]?.move(1),KeyW:()=>games[0]?.rotate(),KeyS:()=>games[0]?.softDrop(true),Space:()=>games[0]?.hardDrop(),
    ArrowLeft:()=>((selectedMode==='solo'||selectedMode==='network')?games[0]:games[1])?.move(-1),ArrowRight:()=>((selectedMode==='solo'||selectedMode==='network')?games[0]:games[1])?.move(1),
    ArrowUp:()=>((selectedMode==='solo'||selectedMode==='network')?games[0]:games[1])?.rotate(),ArrowDown:()=>((selectedMode==='solo'||selectedMode==='network')?games[0]:games[1])?.softDrop(true),
    Enter:()=>((selectedMode==='solo'||selectedMode==='network')?games[0]:games[1])?.hardDrop()
  };
  if(controls[event.code]){event.preventDefault();controls[event.code]();}
});

selectMode('solo'); renderLeaderboard(); renderReplays();
