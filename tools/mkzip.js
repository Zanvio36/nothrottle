// Build the installable KernelSU module zip without external tools.
// Stored (no compression) entries, forward-slash names, deterministic order -
// Windows Compress-Archive writes backslash names, which the manager refuses.
//
//   node tools/mkzip.js module dist/nothrottle-webui-0.4.0.zip
const fs=require('fs'),path=require('path');
const root=process.argv[2], out=process.argv[3];
const files=[];
function walk(d,rel){ for(const e of fs.readdirSync(d,{withFileTypes:true})){ const r=rel?rel+'/'+e.name:e.name; if(e.isDirectory()) walk(path.join(d,e.name),r); else files.push(r); } }
walk(root,'');
files.sort();
const table=(()=>{const t=new Int32Array(256);for(let n=0;n<256;n++){let c=n;for(let k=0;k<8;k++)c=c&1?0xEDB88320^(c>>>1):c>>>1;t[n]=c;}return t;})();
function crc(buf){let c=-1;for(let i=0;i<buf.length;i++)c=table[(c^buf[i])&0xff]^(c>>>8);return (c^-1)>>>0;}
const chunks=[], central=[]; let offset=0; const {DateTime}=globalThis;
const now=new Date();
const dosTime=((now.getHours()<<11)|(now.getMinutes()<<5)|(now.getSeconds()/2|0))&0xffff;
const dosDate=(((now.getFullYear()-1980)<<9)|((now.getMonth()+1)<<5)|now.getDate())&0xffff;
for(const f of files){
  const data=fs.readFileSync(path.join(root,f));
  const name=Buffer.from(f,'utf8'); const c=crc(data);
  const lh=Buffer.alloc(30); lh.writeUInt32LE(0x04034b50,0); lh.writeUInt16LE(20,4); lh.writeUInt16LE(0x0800,6); lh.writeUInt16LE(0,8);
  lh.writeUInt16LE(dosTime,10); lh.writeUInt16LE(dosDate,12); lh.writeUInt32LE(c,14); lh.writeUInt32LE(data.length,18); lh.writeUInt32LE(data.length,22);
  lh.writeUInt16LE(name.length,26); lh.writeUInt16LE(0,28);
  chunks.push(lh,name,data);
  const ch=Buffer.alloc(46); ch.writeUInt32LE(0x02014b50,0); ch.writeUInt16LE(20,4); ch.writeUInt16LE(20,6); ch.writeUInt16LE(0x0800,8); ch.writeUInt16LE(0,10);
  ch.writeUInt16LE(dosTime,12); ch.writeUInt16LE(dosDate,14); ch.writeUInt32LE(c,16); ch.writeUInt32LE(data.length,20); ch.writeUInt32LE(data.length,24);
  ch.writeUInt16LE(name.length,28); ch.writeUInt16LE(0,30); ch.writeUInt16LE(0,32); ch.writeUInt16LE(0,34); ch.writeUInt16LE(0,36); ch.writeUInt32LE(0,38); ch.writeUInt32LE(offset,42);
  central.push(ch,name); offset += 30+name.length+data.length;
}
const cd=Buffer.concat(central);
const end=Buffer.alloc(22); end.writeUInt32LE(0x06054b50,0); end.writeUInt16LE(files.length,8); end.writeUInt16LE(files.length,10); end.writeUInt32LE(cd.length,12); end.writeUInt32LE(offset,16);
fs.writeFileSync(out,Buffer.concat([...chunks,cd,end]));
console.log('zipped',files.length,'files as',files.join(','));
