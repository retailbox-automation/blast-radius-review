/// Field-level comparison of two HL7 messages.
Class BlastRadius.Evidence.Diff Extends %RegisteredObject
{

/// Returns a JSON array of {field, kind, before, after}. Fields are named like ORC-12; kind is lost, added or changed.
/// A repeated segment such as the second ORC is matched to the second ORC on the other side.
ClassMethod Fields(pA As %String, pB As %String) As %String
{
	do ..Segments(pA,.a), ..Segments(pB,.b)
	set out=[]
	merge keys=a,keys=b
	set key=""
	for {
		set key=$order(keys(key)) quit:key=""
		set name=$piece(key,"#",1)
		set hasA=$data(a(key)), hasB=$data(b(key))
		if 'hasA||'hasB {
			do out.%Push({"field":(name),"kind":($select('hasA:"added",1:"lost")),"before":($get(a(key))),"after":($get(b(key)))})
			continue
		}
		set left=a(key), right=b(key)
		set max=$select($length(left,"|")>$length(right,"|"):$length(left,"|"),1:$length(right,"|"))
		for i=2:1:max {
			set va=$piece(left,"|",i), vb=$piece(right,"|",i)
			continue:va=vb
			// MSH fields are numbered from the separator, so MSH-3 is the third field.
			set num=$select(name="MSH":i,1:i-1)
			set kind=$select(vb="":"lost",va="":"added",1:"changed")
			do out.%Push({"field":(name_"-"_num),"kind":(kind),"before":(va),"after":(vb)})
		}
	}
	quit out.%ToJSON()
}

ClassMethod Segments(pRaw As %String, ByRef pSegs)
{
	kill pSegs
	set raw=$translate(pRaw,$char(10),$char(13))
	for i=1:1:$length(raw,$char(13)) {
		set line=$piece(raw,$char(13),i)
		continue:$zstrip(line,"<>W")=""
		set name=$piece(line,"|",1)
		set n=$increment(seen(name))
		set pSegs(name_"#"_n)=line
	}
}

}
