export default async function renderPianoAudition(page, { oldInterval, oldHarmony }) {
 if (new URL(page.url()).origin !== 'http://127.0.0.1:3001') throw new Error('Use the isolated test server');
 const stats=await page.evaluate(async({oldInterval,oldHarmony})=>{
  const classes={};const pins=JSON.parse(document.querySelector('script[type="importmap"]').textContent).imports;
  for(const [name,source] of [['interval',oldInterval],['harmony',oldHarmony]]){
   const old=source.replace(/^import[^\n]*\n/gm,'').replace('export default class extends Controller','class OldPlayer extends Controller');
   classes[name]=[new Function('Controller',old+'\nreturn OldPlayer')(class{}),(await import(pins['controllers/'+name+'_player_controller'])).default];
  }
  const stats=[];window.uxAudition={};
  for(const engine of ['samples','synth']){
   const rendered=[];
   for(let version=0;version<2;version++){
    const context=new OfflineAudioContext(1,48000*15,48000);let offset=0;
    const proxy=new Proxy(context,{get(target,key){if(key==='currentTime')return offset;const v=Reflect.get(target,key,target);return typeof v==='function'?v.bind(target):v}});
    const make=(name,values)=>{
     const c=Object.create(classes[name][version].prototype);
     for(const [key,value] of Object.entries({instrumentValue:'piano',element:{dataset:{}},...values}))Object.defineProperty(c,key,{value,writable:true});
     c.ensureAudioContext=async()=>proxy;c.ensureToneAudioContext=async()=>proxy;
     c.isPlaybackRequestCurrent=()=>true;c.trackPlaybackHandle=()=>{};return c;
    };
    const player=engine==='samples'?await window.Soundfont.instrument(context,'acoustic_grand_piano',{soundfont:'MusyngKite',format:'mp3'}):null;
    const pairs=[['C3','E3',130.8127826503,164.8137784564],['C4','E4',261.6255653006,329.6275569129],['C5','E5',523.2511306012,659.2551138257],['E4','A3',329.6275569129,220]];
    for(const pair of pairs){const c=make('interval',{firstPitchValue:pair[0],secondPitchValue:pair[1],firstFrequencyValue:pair[2],secondFrequencyValue:pair[3]});if(player)await c.playWithSoundfont(player,{});else await c.playWithSynth({});offset+=3;}
    const h=make('harmony',{sequenceValue:[{pitches:['C4','E4','G4','B4'],frequencies:[261.6255653006,329.6275569129,391.9954359817,493.8833012561]}]});
    if(player)await h.playSequenceWithSoundfont(player,'blocked',{});else await h.playSequenceWithSynth('blocked',{});
    const buffer=await context.startRendering();const data=buffer.getChannelData(0);let sum=0,peak=0;
    for(const value of data){if(!Number.isFinite(value))throw Error('nonfinite audio');sum+=value*value;peak=Math.max(peak,Math.abs(value));}
    rendered.push({buffer,rms:Math.sqrt(sum/data.length),peak});
   }
   const rms=Math.min(0.025,...rendered.map(r=>0.8*r.rms/r.peak));
   rendered.forEach((r,i)=>{const gain=rms/r.rms;const data=r.buffer.getChannelData(0);for(let n=0;n<data.length;n++)data[n]*=gain;window.uxAudition[engine+'-'+(i?'after':'before')]=r.buffer;stats.push({engine,version:i?'after':'before',rawRMS:r.rms,rawPeak:r.peak,matchedRMS:rms,matchedPeak:r.peak*gain});});
  }return stats;
 },{oldInterval, oldHarmony});
 for(const name of ['samples-before','samples-after','synth-before','synth-after']){
  const pending=page.waitForEvent('download');
  await page.evaluate(name=>{const b=window.uxAudition[name],data=b.getChannelData(0),bytes=new ArrayBuffer(44+data.length*2),v=new DataView(bytes);
   const text=(offset,s)=>[...s].forEach((c,i)=>v.setUint8(offset+i,c.charCodeAt(0)));
   text(0,'RIFF');v.setUint32(4,36+data.length*2,true);text(8,'WAVE');text(12,'fmt ');v.setUint32(16,16,true);v.setUint16(20,1,true);v.setUint16(22,1,true);v.setUint32(24,b.sampleRate,true);v.setUint32(28,b.sampleRate*2,true);v.setUint16(32,2,true);v.setUint16(34,16,true);text(36,'data');v.setUint32(40,data.length*2,true);for(let i=0;i<data.length;i++)v.setInt16(44+2*i,Math.round(Math.max(-1,Math.min(1,data[i]))*32767),true);
   const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([bytes],{type:'audio/wav'}));a.download=name+'.wav';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000);
  },name);
  await(await pending).saveAs('output/playwright/ux01/piano-'+name+'.wav');
 }return stats;
}
