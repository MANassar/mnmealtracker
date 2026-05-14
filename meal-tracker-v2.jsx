import { useState, useRef, useEffect } from "react";

const DAILY_CAL   = 1800;
const SK          = "meals_v1";
const SETTINGS_SK = "mt_settings_v1";

const C = {
  bg:"#0c1a10",surface:"#111f15",card:"#18281c",border:"rgba(255,255,255,0.06)",
  accent:"#c9a84c",mint:"#6db87a",sky:"#7da8d4",peach:"#d4886a",plum:"#a882c4",
  text:"#f0ece3",muted:"#556358",danger:"#d46a5a",oai:"#74aa9c",
};

/* ── utils ── */
const todayStr    = () => new Date().toISOString().split("T")[0];
const fmtTime     = ts => new Date(ts).toLocaleTimeString([], { hour:"2-digit", minute:"2-digit" });
const fmtDate     = ds => new Date(ds+"T12:00:00").toLocaleDateString("en-GB",{ weekday:"short", day:"numeric", month:"short" });
const sumKey      = (arr,k) => arr.reduce((a,m) => a+(parseFloat(m[k])||0), 0);
const fileToB64   = f => new Promise((res,rej) => {
  const r=new FileReader(); r.onload=()=>res(r.result.split(",")[1]); r.onerror=rej; r.readAsDataURL(f);
});
const groupByDate = meals => {
  const g={};
  meals.forEach(m => { (g[m.date]=g[m.date]||[]).push(m); });
  return Object.entries(g).sort(([a],[b]) => b.localeCompare(a));
};
const loadMeals    = async () => { try { const r=await window.storage.get(SK);          return r?JSON.parse(r.value):[]; }  catch { return [];  } };
const saveMeals    = async m  => { try { await window.storage.set(SK,JSON.stringify(m)); }                                  catch {} };
const loadSettings = async () => { try { const r=await window.storage.get(SETTINGS_SK); return r?JSON.parse(r.value):{}; } catch { return {}; } };
const saveSettings = async s  => { try { await window.storage.set(SETTINGS_SK,JSON.stringify(s)); }                         catch {} };

/* ── API calls ── */
const PROMPT = desc =>
`You are a clinical nutritionist. Analyze the food from the image, description, or both.${desc?` User context: "${desc}"`:""}
Return ONLY a raw JSON object — no markdown, no explanation:
{"mealName":"specific dish name","calories":450,"protein":32.5,"carbs":28.0,"fat":18.5,"fiber":4.2,"ingredients":["item with estimated quantity"],"confidence":"high|medium|low","portionNote":"brief estimation note"}
Calories in kcal. Macros in grams. Do not underestimate portions.`;

async function callAnthropic(img, desc) {
  const content = [
    ...(img ? [{ type:"image", source:{ type:"base64", media_type:img.type, data:img.b64 } }] : []),
    { type:"text", text:PROMPT(desc) },
  ];
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method:"POST", headers:{"Content-Type":"application/json"},
    body:JSON.stringify({ model:"claude-sonnet-4-20250514", max_tokens:1000,
      messages:[{ role:"user", content }],
    }),
  });
  const d = await res.json();
  if (!res.ok) throw new Error(d.error?.message||`HTTP ${res.status}`);
  return (d.content||[]).map(b=>b.text||"").join("");
}

async function callOpenAI(img, desc, key) {
  const content = [
    ...(img ? [{ type:"image_url", image_url:{ url:`data:${img.type};base64,${img.b64}` } }] : []),
    { type:"text", text:PROMPT(desc) },
  ];
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method:"POST", headers:{"Content-Type":"application/json","Authorization":`Bearer ${key}`},
    body:JSON.stringify({ model:"gpt-4o", max_tokens:1000,
      messages:[{ role:"user", content }],
    }),
  });
  const d = await res.json();
  if (!res.ok) throw new Error(d.error?.message||`HTTP ${res.status}`);
  return d.choices?.[0]?.message?.content||"";
}

/* ── CalorieRing ── */
function Ring({ consumed, target }) {
  const r=56,sw=9,circ=2*Math.PI*r,pct=Math.min(consumed/target,1),over=consumed>target;
  return (
    <div style={{position:"relative",width:144,height:144,flexShrink:0}}>
      <svg width="144" height="144" style={{transform:"rotate(-90deg)"}}>
        <circle cx="72" cy="72" r={r} fill="none" stroke={C.card} strokeWidth={sw}/>
        <circle cx="72" cy="72" r={r} fill="none" stroke={over?C.danger:C.accent} strokeWidth={sw}
          strokeDasharray={`${pct*circ} ${circ}`} strokeLinecap="round" style={{transition:"stroke-dasharray .7s ease"}}/>
      </svg>
      <div style={{position:"absolute",inset:0,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",gap:2}}>
        <span style={{fontFamily:"'Playfair Display',serif",fontSize:28,color:over?C.danger:C.text,lineHeight:1}}>{Math.round(consumed)}</span>
        <span style={{fontSize:10,color:C.muted,letterSpacing:".14em",textTransform:"uppercase"}}>/ {target} kcal</span>
      </div>
    </div>
  );
}

/* ── MacroBar ── */
function MBar({ label, value, max, color }) {
  const pct=Math.min((value/max)*100,100);
  return (
    <div style={{flex:1,minWidth:0}}>
      <div style={{display:"flex",justifyContent:"space-between",marginBottom:5}}>
        <span style={{fontSize:10,color:C.muted,textTransform:"uppercase",letterSpacing:".1em"}}>{label}</span>
        <span style={{fontSize:11,color:C.text,fontFamily:"'DM Mono',monospace"}}>{value.toFixed(0)}g</span>
      </div>
      <div style={{height:3,background:C.card,borderRadius:2,overflow:"hidden"}}>
        <div style={{height:"100%",width:`${pct}%`,background:color,borderRadius:2,transition:"width .7s ease"}}/>
      </div>
    </div>
  );
}

/* ── MealCard ── */
function MealCard({ meal, onDelete, onEdit }) {
  const [open,setOpen]=useState(false);
  const m3=[["P",meal.protein,C.mint],["C",meal.carbs,C.sky],["F",meal.fat,C.peach]];
  const m4=[["Protein",meal.protein,C.mint],["Carbs",meal.carbs,C.sky],["Fat",meal.fat,C.peach],["Fiber",meal.fiber||0,C.plum]];
  const provColor = meal.provider==="openai"?C.oai:C.accent;
  return (
    <div onClick={()=>setOpen(!open)} style={{background:C.card,borderRadius:14,overflow:"hidden",border:`1px solid ${C.border}`,marginBottom:10,cursor:"pointer"}}>
      <div style={{display:"flex",alignItems:"stretch"}}>
        {meal.imageData
          ?<img src={`data:${meal.imageType};base64,${meal.imageData}`} style={{width:80,height:80,objectFit:"cover",flexShrink:0}}/>
          :<div style={{width:80,height:80,background:C.surface,flexShrink:0,display:"flex",alignItems:"center",justifyContent:"center",fontSize:26}}>🍽</div>}
        <div style={{flex:1,padding:"10px 12px",minWidth:0}}>
          <div style={{display:"flex",justifyContent:"space-between",alignItems:"flex-start",gap:6}}>
            <span style={{fontFamily:"'Playfair Display',serif",fontSize:14,color:C.text,lineHeight:1.3,flex:1}}>{meal.mealName}</span>
            <span style={{fontSize:14,color:C.accent,fontWeight:700,fontFamily:"'DM Mono',monospace",whiteSpace:"nowrap"}}>{Math.round(meal.calories)}</span>
          </div>
          <div style={{display:"flex",alignItems:"center",gap:6,marginTop:4}}>
            <span style={{fontSize:10,color:C.muted}}>{fmtTime(meal.timestamp)}</span>
            {meal.provider && (
              <span style={{fontSize:9,color:provColor,background:meal.provider==="openai"?"rgba(116,170,156,.12)":"rgba(201,168,76,.12)",padding:"1px 6px",borderRadius:3,letterSpacing:".05em",textTransform:"uppercase"}}>
                {meal.provider==="openai"?"GPT-4o":"Claude"}
              </span>
            )}
          </div>
          <div style={{display:"flex",gap:8,marginTop:6}}>
            {m3.map(([l,v,col])=><span key={l} style={{fontSize:11,color:col,fontFamily:"'DM Mono',monospace"}}>{l} {Number(v).toFixed(0)}g</span>)}
          </div>
        </div>
      </div>
      {open&&(
        <div style={{padding:12,borderTop:`1px solid ${C.border}`}}>
          <div style={{display:"grid",gridTemplateColumns:"repeat(4,1fr)",gap:8,marginBottom:12,background:C.surface,borderRadius:10,padding:"10px 8px"}}>
            {m4.map(([l,v,col])=>(
              <div key={l} style={{textAlign:"center"}}>
                <div style={{fontSize:15,fontWeight:700,color:col,fontFamily:"'DM Mono',monospace"}}>{Number(v).toFixed(0)}g</div>
                <div style={{fontSize:9,color:C.muted,textTransform:"uppercase",letterSpacing:".1em",marginTop:2}}>{l}</div>
              </div>
            ))}
          </div>
          {meal.ingredients?.length>0&&(
            <div style={{marginBottom:8}}>
              <div style={{fontSize:9,color:C.muted,textTransform:"uppercase",letterSpacing:".12em",marginBottom:5}}>Estimated ingredients</div>
              {meal.ingredients.map((i,idx)=><div key={idx} style={{fontSize:12,color:C.text,marginBottom:2}}>· {i}</div>)}
            </div>
          )}
          {meal.portionNote&&<div style={{fontSize:11,color:C.muted,fontStyle:"italic",padding:"8px 10px",background:"rgba(201,168,76,.06)",borderRadius:8,borderLeft:`2px solid ${provColor}`}}>{meal.portionNote}</div>}
          {meal.description&&<div style={{fontSize:11,color:C.muted,marginTop:8}}><span style={{color:C.accent}}>Note:</span> {meal.description}</div>}
          <div style={{display:"flex",gap:10,marginTop:12}}>
            <button onClick={e=>{e.stopPropagation();onEdit(meal);}}
              style={{flex:1,background:"none",border:`1px solid ${provColor}`,color:provColor,borderRadius:8,padding:"0 14px",fontSize:11,cursor:"pointer",height:38}}>
              Modify / re-analyze
            </button>
            <button onClick={e=>{e.stopPropagation();if(confirm("Delete this meal?"))onDelete(meal.id);}}
              style={{background:"none",border:`1px solid ${C.danger}`,color:C.danger,borderRadius:8,padding:"0 14px",fontSize:11,cursor:"pointer",height:38}}>
              Delete
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

/* ── Add Meal View ── */
function AddView({ settings, meal, onSave, onCancel }) {
  const { provider="anthropic", oaiKey="" } = settings;
  const isEditing = Boolean(meal);
  const initialAnalysis = meal ? {
    mealName: meal.mealName, calories: meal.calories,
    protein: meal.protein, carbs: meal.carbs, fat: meal.fat,
    fiber: meal.fiber || 0, ingredients: meal.ingredients || [],
    portionNote: meal.portionNote || "", confidence: meal.confidence || "medium",
  } : null;
  const [img,setImg]           = useState(meal?.imageData?{url:`data:${meal.imageType};base64,${meal.imageData}`,b64:meal.imageData,type:meal.imageType}:null);
  const [desc,setDesc]         = useState(meal?.description || "");
  const [status,setStatus]     = useState(meal?"review":"idle");
  const [analysis,setAnalysis] = useState(initialAnalysis);
  const [editCal,setEditCal]   = useState(meal?String(Math.round(meal.calories)):"");
  const [err,setErr]           = useState("");
  const fileRef = useRef();
  const provColor = provider==="openai"?C.oai:C.accent;

  const pick = async e => {
    const f=e.target.files?.[0]; if(!f) return;
    setAnalysis(null); setStatus("idle");
    setImg({ url:URL.createObjectURL(f), b64:await fileToB64(f), type:f.type });
  };

  const analyze = async () => {
    const trimmedDesc = desc.trim();
    if (!img && !trimmedDesc) { setErr("Please add a photo, a description, or both."); return; }
    if (provider==="openai"&&!oaiKey) { setErr("OpenAI key missing — add it in Settings."); return; }
    setStatus("analyzing"); setErr("");
    try {
      const raw = provider==="openai"
        ? await callOpenAI(img, trimmedDesc, oaiKey)
        : await callAnthropic(img, trimmedDesc);
      const parsed = JSON.parse(raw.replace(/```json|```/gi,"").trim());
      setAnalysis(parsed); setEditCal(String(Math.round(parsed.calories))); setStatus("review");
    } catch(e) { setErr(`Analysis failed: ${e.message}`); setStatus("error"); }
  };

  const log = () => {
    if (!analysis) return;
    onSave({ id:meal?.id||Date.now(), date:meal?.date||todayStr(), timestamp:meal?.timestamp||new Date().toISOString(),
      updatedAt:isEditing?new Date().toISOString():undefined,
      description:desc.trim(), provider,
      imageData:img?.b64||null, imageType:img?.type||null,
      mealName:analysis.mealName,
      calories:parseInt(editCal)||analysis.calories,
      protein:analysis.protein, carbs:analysis.carbs,
      fat:analysis.fat, fiber:analysis.fiber||0,
      ingredients:analysis.ingredients||[],
      portionNote:analysis.portionNote||"",
      confidence:analysis.confidence||"medium",
    });
  };

  return (
    <div style={{display:"flex",flexDirection:"column",height:"100%",minHeight:0}}>
      <div style={{padding:"16px 16px 12px",flexShrink:0,borderBottom:`1px solid ${C.border}`}}>
        <div style={{display:"flex",alignItems:"center",gap:12}}>
          <button onClick={onCancel} style={{background:"none",border:"none",color:C.muted,cursor:"pointer",fontSize:22,minWidth:44,minHeight:44,display:"flex",alignItems:"center",justifyContent:"center"}}>←</button>
          <span style={{fontFamily:"'Playfair Display',serif",fontSize:22,color:C.text,flex:1}}>{isEditing?"Edit Meal":"Add Meal"}</span>
          <span style={{fontSize:10,color:provColor,background:provider==="openai"?"rgba(116,170,156,.12)":"rgba(201,168,76,.12)",padding:"4px 10px",borderRadius:20,border:`1px solid ${provColor}`,letterSpacing:".06em",textTransform:"uppercase",fontWeight:600}}>
            {provider==="openai"?"GPT-4o":"Claude"}
          </span>
        </div>
      </div>

      <div style={{flex:1,minHeight:0,overflowY:"scroll",WebkitOverflowScrolling:"touch",overscrollBehaviorY:"auto",touchAction:"pan-y",padding:"14px 16px"}}>
        <div onClick={()=>!img&&fileRef.current?.click()}
          style={{borderRadius:16,overflow:"hidden",marginBottom:12,background:C.card,
            border:img?`1px solid ${C.border}`:`2px dashed ${C.muted}`,
            cursor:img?"default":"pointer",...(!img&&{minHeight:160,display:"flex",alignItems:"center",justifyContent:"center"})}}>
          {img?(
            <div style={{position:"relative"}}>
              <img src={img.url} style={{width:"100%",maxHeight:240,objectFit:"cover",display:"block"}}/>
              <button onClick={e=>{e.stopPropagation();setImg(null);setAnalysis(null);setStatus("idle");fileRef.current.value="";}}
                style={{position:"absolute",top:10,right:10,background:"rgba(0,0,0,.65)",border:"none",color:C.text,borderRadius:"50%",width:36,height:36,cursor:"pointer",fontSize:18,display:"flex",alignItems:"center",justifyContent:"center"}}>×</button>
            </div>
          ):(
            <div style={{textAlign:"center",color:C.muted,padding:20}}>
              <div style={{fontSize:42,marginBottom:8}}>📷</div>
              <div style={{fontSize:15,fontWeight:500}}>Add a photo</div>
              <div style={{fontSize:12,marginTop:3}}>optional if you describe the meal</div>
            </div>
          )}
        </div>
        <input ref={fileRef} type="file" accept="image/*" onChange={pick} style={{display:"none"}}/>

        <textarea value={desc} onChange={e=>setDesc(e.target.value)}
          placeholder="Describe the meal, portions, ingredients, or restaurant…" rows={3}
          style={{width:"100%",background:C.card,border:`1px solid ${C.border}`,borderRadius:10,color:C.text,fontSize:16,padding:14,outline:"none",resize:"none",marginBottom:12,fontFamily:"'DM Sans',sans-serif",boxSizing:"border-box"}}/>

        {err&&<div style={{background:"rgba(212,106,90,.12)",border:`1px solid ${C.danger}`,borderRadius:10,padding:12,color:C.danger,fontSize:13,marginBottom:12,lineHeight:1.4}}>{err}</div>}

        {status==="review"&&analysis&&(
          <div style={{background:C.card,border:`1px solid rgba(${provider==="openai"?"116,170,156":"201,168,76"},.2)`,borderRadius:16,padding:14,marginBottom:12}}>
            <div style={{fontFamily:"'Playfair Display',serif",fontSize:18,color:C.text,marginBottom:12}}>{analysis.mealName}</div>
            <div style={{display:"flex",alignItems:"center",gap:8,background:C.surface,borderRadius:10,padding:"10px 12px",marginBottom:12}}>
              <span style={{fontSize:12,color:C.muted,flex:1}}>Calories</span>
              <input type="number" value={editCal} onChange={e=>setEditCal(e.target.value)}
                style={{width:72,background:"transparent",border:"none",borderBottom:`1px solid ${provColor}`,color:provColor,fontSize:22,fontFamily:"'DM Mono',monospace",fontWeight:700,textAlign:"center",outline:"none",padding:"2px 0"}}/>
              <span style={{fontSize:12,color:C.muted}}>kcal</span>
            </div>
            <div style={{display:"grid",gridTemplateColumns:"repeat(4,1fr)",gap:8,marginBottom:12}}>
              {[["Protein",analysis.protein,C.mint],["Carbs",analysis.carbs,C.sky],["Fat",analysis.fat,C.peach],["Fiber",analysis.fiber||0,C.plum]].map(([l,v,col])=>(
                <div key={l} style={{background:C.surface,borderRadius:10,padding:"10px 4px",textAlign:"center"}}>
                  <div style={{fontSize:16,fontWeight:700,color:col,fontFamily:"'DM Mono',monospace"}}>{Number(v).toFixed(1)}</div>
                  <div style={{fontSize:9,color:C.muted,textTransform:"uppercase",letterSpacing:".1em",marginTop:3}}>{l}</div>
                </div>
              ))}
            </div>
            {analysis.portionNote&&<div style={{fontSize:11,color:C.muted,fontStyle:"italic",padding:"8px 10px",background:`rgba(${provider==="openai"?"116,170,156":"201,168,76"},.06)`,borderRadius:8,borderLeft:`2px solid ${provColor}`}}>{analysis.portionNote}</div>}
          </div>
        )}
      </div>

      <div style={{padding:"10px 16px 10px",borderTop:`1px solid ${C.border}`,flexShrink:0}}>
        {status!=="review"?(
          <button onClick={analyze}
            style={{width:"100%",padding:16,background:!img&&!desc.trim()?C.muted:provColor,border:"none",borderRadius:14,fontSize:15,fontWeight:700,color:!img&&!desc.trim()?C.surface:"#0c1a10",cursor:!img&&!desc.trim()?"not-allowed":"pointer",minHeight:54,opacity:status==="analyzing"?.7:1}}>
            {status==="analyzing"?"Analyzing…":"Analyze Meal"}
          </button>
        ):(
          <div style={{display:"flex",gap:10}}>
            <button onClick={analyze}
              style={{flex:1,padding:16,background:"none",border:`1px solid ${C.muted}`,borderRadius:14,fontSize:14,color:C.muted,cursor:"pointer",minHeight:54}}>Re-analyze</button>
            <button onClick={log}
              style={{flex:2,padding:16,background:provColor,border:"none",borderRadius:14,fontSize:15,fontWeight:700,color:"#0c1a10",cursor:"pointer",minHeight:54}}>{isEditing?"Save Meal ✓":"Log Meal ✓"}</button>
          </div>
        )}
      </div>
    </div>
  );
}

/* ── Today View ── */
function TodayView({ meals, onDelete, onEdit, onSettings }) {
  const today  = meals.filter(m=>m.date===todayStr());
  const cal    = sumKey(today,"calories"), protein=sumKey(today,"protein");
  const carbs  = sumKey(today,"carbs"),   fat=sumKey(today,"fat");
  const rem    = DAILY_CAL-cal;
  const sorted = [...today].sort((a,b)=>new Date(b.timestamp)-new Date(a.timestamp));
  const label  = new Date().toLocaleDateString("en-GB",{weekday:"long",day:"numeric",month:"long"});
  return (
    <div style={{display:"flex",flexDirection:"column",height:"100%"}}>
      <div style={{display:"flex",justifyContent:"space-between",alignItems:"center",padding:"16px 16px 0",flexShrink:0}}>
        <span style={{fontSize:10,color:C.muted,textTransform:"uppercase",letterSpacing:".18em"}}>{label}</span>
        <button onClick={onSettings} style={{background:"none",border:"none",color:C.muted,cursor:"pointer",fontSize:20,minWidth:44,minHeight:44,display:"flex",alignItems:"center",justifyContent:"center"}}>⚙</button>
      </div>
      <div style={{flex:1,minHeight:0,overflowY:"scroll",WebkitOverflowScrolling:"touch",overscrollBehaviorY:"auto",touchAction:"pan-y",padding:"0 16px 80px"}}>
        <div style={{minHeight:"calc(100% + 1px)"}}>
          <div style={{display:"flex",justifyContent:"center",padding:"16px 0 12px"}}><Ring consumed={Math.round(cal)} target={DAILY_CAL}/></div>
          <div style={{textAlign:"center",fontSize:12,fontFamily:"'DM Mono',monospace",marginBottom:18,color:rem>=0?C.mint:C.danger}}>
            {rem>=0?`${Math.round(rem)} kcal remaining`:`${Math.abs(Math.round(rem))} kcal over target`}
          </div>
          <div style={{display:"flex",gap:14,marginBottom:24}}>
            <MBar label="Protein" value={protein} max={150} color={C.mint}/>
            <MBar label="Carbs"   value={carbs}   max={180} color={C.sky}/>
            <MBar label="Fat"     value={fat}     max={60}  color={C.peach}/>
          </div>
          <div style={{display:"flex",justifyContent:"space-between",alignItems:"baseline",marginBottom:10}}>
            <span style={{fontFamily:"'Playfair Display',serif",fontSize:12,color:C.muted,textTransform:"uppercase",letterSpacing:".12em"}}>
              {today.length===0?"No meals logged yet":`${today.length} Meal${today.length>1?"s":""} today`}
            </span>
            {today.length>0&&<span style={{fontSize:10,color:C.muted,fontFamily:"'DM Mono',monospace"}}>{protein.toFixed(0)}P·{carbs.toFixed(0)}C·{fat.toFixed(0)}F</span>}
          </div>
          {sorted.map(m=><MealCard key={m.id} meal={m} onDelete={onDelete} onEdit={onEdit}/>)}
          {today.length===0&&(
            <div style={{textAlign:"center",paddingTop:36,color:C.muted}}>
              <div style={{fontSize:36,marginBottom:10}}>🍽</div>
              <div style={{fontSize:14}}>Tap <strong style={{color:C.accent}}>+</strong> to log your first meal</div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

/* ── History View ── */
function HistView({ meals, onDelete, onEdit }) {
  const groups = groupByDate(meals);
  return (
    <div style={{display:"flex",flexDirection:"column",height:"100%",minHeight:0}}>
      <div style={{padding:"16px 16px 0",flexShrink:0}}>
        <div style={{fontFamily:"'Playfair Display',serif",fontSize:24,color:C.text,paddingBottom:14}}>History</div>
      </div>
      <div style={{flex:1,minHeight:0,overflowY:"scroll",WebkitOverflowScrolling:"touch",overscrollBehaviorY:"auto",touchAction:"pan-y",padding:"0 16px 80px"}}>
        <div style={{minHeight:"calc(100% + 1px)"}}>
          {groups.length===0&&<div style={{textAlign:"center",paddingTop:48,color:C.muted,fontSize:14}}>Meals will appear here after you log them.</div>}
          {groups.map(([date,dayMeals])=>{
            const cal=sumKey(dayMeals,"calories"),p=sumKey(dayMeals,"protein"),c=sumKey(dayMeals,"carbs"),f=sumKey(dayMeals,"fat"),over=cal>DAILY_CAL;
            const sortedDayMeals=[...dayMeals].sort((a,b)=>new Date(b.timestamp)-new Date(a.timestamp));
            return (
              <div key={date} style={{marginBottom:24}}>
                <div style={{display:"flex",justifyContent:"space-between",alignItems:"flex-start",gap:12,marginBottom:8}}>
                  <div>
                    <div style={{fontFamily:"'Playfair Display',serif",fontSize:17,color:C.text}}>{fmtDate(date)}</div>
                    <div style={{fontSize:10,color:C.muted,textTransform:"uppercase",letterSpacing:".1em",marginTop:3}}>
                      {dayMeals.length} Meal{dayMeals.length===1?"":"s"}
                    </div>
                  </div>
                  <div style={{textAlign:"right"}}>
                    <div style={{fontSize:16,color:over?C.danger:C.mint,fontFamily:"'DM Mono',monospace",fontWeight:700}}>{Math.round(cal)} kcal</div>
                    <div style={{fontSize:10,color:C.muted,fontFamily:"'DM Mono',monospace",marginTop:3}}>{p.toFixed(0)}P · {c.toFixed(0)}C · {f.toFixed(0)}F</div>
                  </div>
                </div>
                <div style={{height:2,background:C.card,borderRadius:1,marginBottom:8}}>
                  <div style={{height:"100%",width:`${Math.min((cal/DAILY_CAL)*100,100)}%`,background:over?C.danger:C.accent,borderRadius:1}}/>
                </div>
                {sortedDayMeals.map(m=><MealCard key={m.id} meal={m} onDelete={onDelete} onEdit={onEdit}/>)}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

/* ── Settings View ── */
function SettView({ settings, onSave, onBack }) {
  const [provider, setProvider] = useState(settings.provider||"anthropic");
  const [oaiKey,   setOaiKey]   = useState(settings.oaiKey||"");
  const [saved,    setSaved]    = useState(false);

  const save = () => { onSave({ provider, oaiKey }); setSaved(true); setTimeout(()=>setSaved(false),2000); };

  const ProvTab = ({ id, label, sub }) => {
    const active = provider===id;
    const col    = id==="openai"?C.oai:C.accent;
    return (
      <button onClick={()=>setProvider(id)} style={{flex:1,padding:"12px 8px",borderRadius:10,
        border:`1px solid ${active?col:C.border}`,
        background:active?`rgba(${id==="openai"?"116,170,156":"201,168,76"},.1)`:"none",
        cursor:"pointer",textAlign:"center",transition:"all .2s"}}>
        <div style={{fontSize:13,fontWeight:600,color:active?col:C.muted}}>{label}</div>
        <div style={{fontSize:10,color:C.muted,marginTop:2}}>{sub}</div>
      </button>
    );
  };

  return (
    <div style={{display:"flex",flexDirection:"column",height:"100%"}}>
      <div style={{padding:"16px 16px 12px",flexShrink:0,borderBottom:`1px solid ${C.border}`}}>
        <div style={{display:"flex",alignItems:"center",gap:12}}>
          <button onClick={onBack} style={{background:"none",border:"none",color:C.muted,cursor:"pointer",fontSize:22,minWidth:44,minHeight:44,display:"flex",alignItems:"center",justifyContent:"center"}}>←</button>
          <span style={{fontFamily:"'Playfair Display',serif",fontSize:22,color:C.text}}>Settings</span>
        </div>
      </div>

      <div style={{flex:1,minHeight:0,overflowY:"scroll",WebkitOverflowScrolling:"touch",overscrollBehaviorY:"auto",touchAction:"pan-y",padding:"20px 16px"}}>

        {/* Provider tabs */}
        <div style={{fontSize:11,color:C.muted,textTransform:"uppercase",letterSpacing:".1em",marginBottom:10}}>AI Provider</div>
        <div style={{display:"flex",gap:10,marginBottom:20}}>
          <ProvTab id="anthropic" label="Anthropic" sub="Claude Sonnet 4"/>
          <ProvTab id="openai"    label="OpenAI"    sub="GPT-4o"/>
        </div>

        {/* Anthropic — no key needed inside Claude.ai */}
        {provider==="anthropic"&&(
          <div style={{padding:12,background:C.card,border:"1px solid rgba(201,168,76,.2)",borderRadius:10,marginBottom:20}}>
            <div style={{fontSize:13,color:C.text,fontWeight:600,marginBottom:4}}>✓ No key required</div>
            <div style={{fontSize:12,color:C.muted,lineHeight:1.5}}>Running inside Claude.ai — API access is handled automatically.</div>
          </div>
        )}

        {/* OpenAI key */}
        {provider==="openai"&&(
          <>
            <div style={{fontSize:11,color:C.muted,textTransform:"uppercase",letterSpacing:".1em",marginBottom:8}}>OpenAI API Key</div>
            <input type="password" value={oaiKey} onChange={e=>setOaiKey(e.target.value)}
              placeholder="sk-proj-…"
              style={{width:"100%",background:C.card,border:`1px solid ${C.border}`,borderRadius:10,color:C.text,fontSize:16,padding:14,outline:"none",fontFamily:"'DM Mono',monospace",boxSizing:"border-box",marginBottom:8}}/>
            <div style={{fontSize:11,color:C.muted,marginBottom:20,lineHeight:1.5}}>
              Stored only on this device.{" "}
              <span style={{color:C.oai}}>platform.openai.com/api-keys</span>
            </div>
          </>
        )}

        <button onClick={save}
          style={{width:"100%",padding:16,background:provider==="openai"?C.oai:C.accent,border:"none",borderRadius:14,fontSize:15,fontWeight:700,color:"#0c1a10",cursor:"pointer",minHeight:54,marginBottom:24}}>
          {saved?"Saved ✓":"Save Settings"}
        </button>

        <div style={{fontSize:12,color:C.muted,lineHeight:1.9,padding:14,background:C.card,borderRadius:12}}>
          <div style={{color:C.text,fontWeight:600,marginBottom:8}}>Daily Targets</div>
          <div>Calories: <span style={{color:C.text}}>{DAILY_CAL} kcal</span></div>
          <div>Protein: <span style={{color:C.mint}}>150g</span> · Carbs: <span style={{color:C.sky}}>180g</span> · Fat: <span style={{color:C.peach}}>60g</span></div>
        </div>
      </div>
    </div>
  );
}

/* ── Root ── */
export default function App() {
  const [meals,   setMeals]    = useState([]);
  const [settings,setSettings] = useState({ provider:"anthropic", oaiKey:"" });
  const [ready,   setReady]    = useState(false);
  const [view,    setView]     = useState("today");
  const [editingMeal,setEditingMeal] = useState(null);
  const [editReturnView,setEditReturnView] = useState("today");

  useEffect(() => {
    Promise.all([loadMeals(), loadSettings()]).then(([m,s]) => {
      setMeals(m);
      setSettings(prev=>({...prev,...s}));
      setReady(true);
    });
  }, []);

  const addMeal      = async meal => { const u=[meal,...meals]; setMeals(u); await saveMeals(u); setView("today"); };
  const updateMeal   = async meal => { const u=meals.map(m=>m.id===meal.id?meal:m); setMeals(u); await saveMeals(u); setEditingMeal(null); setView(editReturnView); };
  const saveMeal     = meal => editingMeal ? updateMeal(meal) : addMeal(meal);
  const editMeal     = meal => { setEditingMeal(meal); setEditReturnView(view); setView("add"); };
  const deleteMeal   = async id   => { const u=meals.filter(m=>m.id!==id); setMeals(u); await saveMeals(u); };
  const updateSettings = async s  => { setSettings(s); await saveSettings(s); };

  const NAV = [
    { key:"today",   icon:"◉", label:"Today"   },
    { key:"add",     icon:"+", label:"Add"      },
    { key:"history", icon:"≡", label:"History"  },
  ];

  if (!ready) return (
    <div style={{background:C.bg,height:"100%",display:"flex",alignItems:"center",justifyContent:"center",fontFamily:"'DM Sans',sans-serif",color:C.muted}}>Loading…</div>
  );

  const navAccent = settings.provider==="openai"?C.oai:C.accent;

  return (
    <>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;1,400&family=DM+Sans:wght@400;500;700&family=DM+Mono&display=swap');
        *,*::before,*::after{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}
        body{background:${C.bg}}
        input,textarea{font-size:16px!important}
        input[type=number]::-webkit-inner-spin-button{-webkit-appearance:none}
        ::-webkit-scrollbar{display:none}
      `}</style>
      <div style={{background:C.bg,height:"100%",maxWidth:480,margin:"0 auto",fontFamily:"'DM Sans',sans-serif",color:C.text,display:"flex",flexDirection:"column",overflow:"hidden"}}>
        <div style={{flex:1,overflow:"hidden",minHeight:0}}>
          {view==="add"      ?<AddView key={editingMeal?.id||"new"} settings={settings} meal={editingMeal} onSave={saveMeal} onCancel={()=>{setEditingMeal(null);setView(editingMeal?editReturnView:"today");}}/>:
           view==="settings" ?<SettView settings={settings} onSave={s=>{updateSettings(s);setView("today");}} onBack={()=>setView("today")}/>:
           view==="history"  ?<HistView meals={meals} onDelete={deleteMeal} onEdit={editMeal}/>:
                              <TodayView meals={meals} onDelete={deleteMeal} onEdit={editMeal} onSettings={()=>setView("settings")}/>}
        </div>
        {view!=="add"&&view!=="settings"&&(
          <div style={{flexShrink:0,display:"flex",background:"rgba(12,26,16,.97)",borderTop:`1px solid ${C.border}`}}>
            {NAV.map(item=>{
              const isAdd=item.key==="add",active=view===item.key;
              return (
                <button key={item.key} onClick={()=>{setEditingMeal(null);setView(item.key);}}
                  style={{flex:1,padding:isAdd?"8px 0 14px":"12px 0 14px",background:isAdd?navAccent:"none",border:"none",cursor:"pointer",display:"flex",flexDirection:"column",alignItems:"center",gap:4,color:isAdd?"#0c1a10":active?navAccent:C.muted,transition:"color .2s",minHeight:52}}>
                  <span style={{fontSize:isAdd?24:16,lineHeight:1}}>{item.icon}</span>
                  <span style={{fontSize:9,textTransform:"uppercase",letterSpacing:".12em",fontWeight:500}}>{item.label}</span>
                </button>
              );
            })}
          </div>
        )}
      </div>
    </>
  );
}
