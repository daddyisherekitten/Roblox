// Decode the lossless 8-bit RGB/RGBA PNGs returned by Chromium CDP.
const zlib=require('node:zlib');
module.exports=function pixels(data){
 const input=Buffer.from(data,'base64'),parts=[];let width,height,channels;
 for(let at=8;at<input.length;){const size=input.readUInt32BE(at),kind=input.toString('ascii',at+4,at+8),body=input.subarray(at+8,at+8+size);at+=size+12;
  if(kind==='IHDR'){width=body.readUInt32BE(0);height=body.readUInt32BE(4);channels=body[9]===2?3:body[9]===6?4:0;if(body[8]!==8||!channels||body[12])throw Error('Unsupported native PNG format');}
  else if(kind==='IDAT')parts.push(body);
 }
 const raw=zlib.inflateSync(Buffer.concat(parts)),stride=width*channels,out=Buffer.alloc(height*stride);
 const paeth=(a,b,c)=>{const p=a+b-c,pa=Math.abs(p-a),pb=Math.abs(p-b),pc=Math.abs(p-c);return pa<=pb&&pa<=pc?a:pb<=pc?b:c;};
 for(let y=0;y<height;y++){const filter=raw[y*(stride+1)];for(let x=0;x<stride;x++){
  const a=x>=channels?out[y*stride+x-channels]:0,b=y?out[(y-1)*stride+x]:0,c=y&&x>=channels?out[(y-1)*stride+x-channels]:0;
  const value=filter===0?0:filter===1?a:filter===2?b:filter===3?Math.floor((a+b)/2):filter===4?paeth(a,b,c):NaN;
  if(!Number.isFinite(value))throw Error('Unsupported native PNG filter');out[y*stride+x]=(raw[y*(stride+1)+x+1]+value)&255;
 }}return {out,width,height,channels};
};
