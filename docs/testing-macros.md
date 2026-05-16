# QuestieLearner In-Game Testing Macros

Copy these into WoW's `/macro` interface (one per macro button).
Use `/run` to execute raw Lua from a macro.

---

## Macro 1: Learner Stats
Shows how much data QuestieLearner has collected.

```
/run local QL=QuestieLoader:ImportModule("QuestieLearner")local n,q,i,o=QL:GetStats()print("Learner: "..n.." NPCs, "..q.." quests, "..i.." items, "..o.." objects")
```

---

## Macro 2: Dump Current Target
Prints what QuestieLearner knows about your current target.

```
/run local t="target"local g=UnitGUID(t)if not g then print("No target")return end local nid=tonumber(g:match("%-(%d+)%-[^-]+$"))if not nid then print("Can't parse NPC ID")return end local d=QuestieLoader:ImportModule("QuestieLearner").dbLearner.global.npcs[nid]if d then print("NPC "..nid..": "..tostring(d[1]))for z,c in pairs(d[7] or {})do print("  Zone "..z..": "..#c.." coords")for _,v in ipairs(c)do print("    ("..v[1]..", "..v[2]..")")end end else print("No learned data for NPC "..nid)end
```

---

## Macro 3: Dump Mouseover
Same as above, but reads your mouseover unit.

```
/run local t="mouseover"local g=UnitGUID(t)if not g then print("No mouseover")return end local nid=tonumber(g:match("%-(%d+)%-[^-]+$"))if not nid then print("Can't parse NPC ID")return end local d=QuestieLoader:ImportModule("QuestieLearner").dbLearner.global.npcs[nid]if d then print("NPC "..nid..": "..tostring(d[1]))for z,c in pairs(d[7] or {})do print("  Zone "..z..": "..#c.." coords")for _,v in ipairs(c)do print("    ("..v[1]..", "..v[2]..")")end end else print("No learned data for NPC "..nid)end
```

---

## Macro 4: Zone Info
Shows current zone's areaId, uiMapId, and name — useful for verifying zone mapping.

```
/run local n=GetRealZoneText()local u=C_Map.GetBestMapForUnit("player")local a=select(8,GetInstanceInfo())local zd=QuestieLoader:ImportModule("ZoneDB")if zd and zd.GetAreaIdByUiMapId then local aid=zd:GetAreaIdByUiMapId(u)if aid and aid>0 then a=aid end end print("Zone: "..n.." | uiMapId: "..tostring(u).." | areaId: "..tostring(a))
```

---

## Macro 5: Debug Toggle
Toggles Questie's DEVELOP debug level to see [QL-DEV] learner prints.

```
/run local q=Questie if q.db.profile.debugEnabled then q.db.profile.debugEnabled=not q.db.profile.debugEnabled;q.db.profile.debugLevel=0;print("Debug OFF")else q.db.profile.debugEnabled=true;q.db.profile.debugLevel=16384;print("Debug ON (DEVELOP level)")end
```

---

## Macro 6: Force Learn Mouseover
Manually triggers QuestieLearner to record the mouseover NPC's location.

```
/run local mo="mouseover"if UnitExists(mo)and not UnitIsPlayer(mo)then local g=UnitGUID(mo)local nid=tonumber(g:match("%-(%d+)%-[^-]+$"))if nid then local QL=QuestieLoader:ImportModule("QuestieLearner")local name=UnitName(mo)local level=UnitLevel(mo)local flags=UnitNPCFlags and UnitNPCFlags(mo)or 0 local a=l10n and l10n.GetAreaId and l10n:GetAreaId()QL:LearnNPC(nid,name,level,nil,flags,nil,nil,nil,a)print("Learned "..name.." ("..nid..") in zone "..tostring(a))end else print("No valid mouseover target")end
```

---

## Macro 7: Re-inject Data
Forces QuestieLearner to re-process all learned data (zone migration, override injection). Use after importing data or if pins aren't showing.

```
/run QuestieLoader:ImportModule("QuestieLearner"):InjectLearnedData()print("Data re-injected")
```

---

## Usage Notes

- These use WoW's 255-character macro limit; they've been compressed to fit.
- Run each macro once after creating it to verify it works.
- Enable Debug (Macro 5) first to see `[QL-DEV]` prints for learning events.
- Use Macro 4 to check which zone/areaId you're in when testing.
- If a macro doesn't fit, split it into two macros.
