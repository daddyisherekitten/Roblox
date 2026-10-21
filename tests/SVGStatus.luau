--!strict
return function(load)
 local lines={}
 local stats={Builds=1,Rasters=1,CacheHits=0,Uploads=1,HitBuilds=1,Cancelled=0,BuildMS=12,RasterMS=80,LastWidth=480,LastHeight=720}
 local report=load({SVGStats=stats},function(s) table.insert(lines,s) end)
 report();assert(#lines==1 and lines[1]:find('Szenen%-Neuaufbau') and lines[1]:find('480x720'))
 report();assert(#lines==1,'Same completed batch is reported once')
 stats.Uploads+=1;stats.CacheHits+=1
 report();assert(lines[2]:find('Cache wiederverwendet') and lines[2]:find('Hitbox%-Aufbau: 0') and lines[2]:find('Szenen: 0'))
 stats.Uploads+=1;stats.Rasters+=1;stats.RasterMS+=23
 report();assert(lines[3]:find('Pixel%-Neuberechnung') and lines[3]:find('23.0 ms',1,true))
 stats.Uploads+=1;stats.Rasters+=1;stats.RasterActiveMS=12;stats.RasterWaitMS=35;stats.LayerHits=4;stats.LayerBuilds=1
 report();assert(lines[4]:find('Arbeit: 12.0 ms, Warten: 35.0 ms',1,true) and lines[4]:find('Ebenen: 4 wiederverwendet, 1 erstellt',1,true))
 stats.Uploads+=1;stats.Rasters+=1;stats.Builds+=1;stats.PartialRenders=1;stats.RepaintPixels=500
 report();assert(lines[5]:find('Teilbereich neu gerastert',1,true) and lines[5]:find('Neu gerasterte Fläche: 500 px',1,true))
 stats.WarmQueued=3;stats.WarmCompleted=1;stats.CacheBytes=1024*1024
 report();assert(lines[6]:find('Hover vorbereitet',1,true) and lines[6]:find('Fertig: 1/3',1,true) and lines[6]:find('Wartend: 2',1,true) and lines[6]:find('1.0 MB',1,true))
 report();assert(#lines==6,'Unchanged preparation progress is reported once')
 print('SVG status: scene/raster/cache distinction, prewarm progress, per-batch deltas, dimensions and duplicate suppression passed')
end
