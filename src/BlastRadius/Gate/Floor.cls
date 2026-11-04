/// The code half of "the agent proposes, code decides".
/// It reads what the tools actually returned, never the agent's prose, and works out the softest verdict the evidence allows.
/// It looks at the items the decision names, the items the request names and the routers in front of them, and checks what the agent skipped.
/// The agent may be stricter than this floor, never softer. What neither the decision nor the request names is outside it.
Class BlastRadius.Gate.Floor Extends %RegisteredObject
{

/// Mildest first.
Parameter ORDER = "APPLY,APPLY-AFTER-DRAIN,CANARY-FIRST,HOLD";

/// The traffic window the rules are written for. A shorter look cannot clear anything.
Parameter WINDOWDAYS = 30;

ClassMethod Rank(pVerdict As %String) As %Integer
{
	set order=..#ORDER
	for i=1:1:$length(order,",") { if $piece(order,",",i)=pVerdict quit }
	quit $select($piece(order,",",i)=pVerdict:i,1:0)
}

/// Returns {verdict, floor, reasons:[...], tasks:[{key,item,reason}]}.
/// pEvidence: {items_checked, traffic:[...], queue:[...], shadow:[...]} as recorded by the tools.
/// pDecision: the arguments of SubmitDecision, or "" if the agent never submitted.
/// pAnswers: JSON array of owner answers from Workflow, or "".
ClassMethod Decide(pEvidence As %DynamicObject, pDecision, pRequestText As %String, pAnswers As %DynamicArray = "") As %DynamicObject
{
	set reasons=[], tasks=[]
	set floor="APPLY"
	if '$isobject(pDecision) {
		do reasons.%Push("The agent did not submit a decision.")
		quit ..Result("HOLD","",reasons,tasks)
	}
	set proposed=pDecision.verdict
	if ..Rank(proposed)=0 {
		do reasons.%Push("The agent proposed an unknown verdict: "_proposed)
		set floor="HOLD"
	}
	// Owners' answers from the Workflow inbox.
	if $isobject(pAnswers) {
		set it=pAnswers.%GetIterator()
		while it.%GetNext(.k,.a) { set answers(a.key)=a.action }
	}
	// Rule 0: an owner who did not confirm stops the change, whether or not this round's evidence still shows their point.
	set key=""
	for {
		set key=$order(answers(key),1,action) quit:key=""
		continue:action="Confirm"
		do reasons.%Push($select($piece(key,":")="sender":"The owner of "_$piece(key,":",2,*)_" rejected this change.",$piece(key,":")="diff":"An owner rejected the change to "_$piece(key,":",2,*)_".",1:"An owner answered "_action_" on "_key_"."))
		set refused(key)=""
		set floor="HOLD"
	}

	// Rule 1: a review needs evidence for everything it names. If the agent skipped a check, the gate runs it itself and judges the result.
	set items=pDecision.items
	if '$isobject(items)||(items.%Size()=0) {
		do reasons.%Push("The agent named no production items.")
		set floor="HOLD"
	}
	if '$isobject(pEvidence.traffic) { do pEvidence.%Set("traffic",[]) }
	if '$isobject(pEvidence.queue) { do pEvidence.%Set("queue",[]) }
	set it=pEvidence.traffic.%GetIterator()
	while it.%GetNext(.k,.t) { if +t."window_days">=..#WINDOWDAYS { set checked(t.item)="" } }
	set it=pEvidence.queue.%GetIterator()
	while it.%GetNext(.k,.q) { set queued(q.item)="" }
	if $isobject(items) {
		set hosts=0
		set it=items.%GetIterator()
		while it.%GetNext(.k,.name) { set:..IsHost(name) hosts=hosts+1 }
		// An agent can leave an item out, so the gate also looks at what the request names and at the routers in front.
		do ..Scope(items,pRequestText,.lookAt,.touched)
		set name=""
		for {
			set name=$order(lookAt(name)) quit:name=""
			continue:$data(checked(name))
			try { set t=##class(BlastRadius.Evidence.Traffic).Links(name,..#WINDOWDAYS) } catch ex { set t={"item":(name),"window_days":(..#WINDOWDAYS),"error":(ex.DisplayString())} }
			do pEvidence.traffic.%Push(t)
			set checked(name)=""
		}
		set name=""
		for {
			set name=$order(touched(name)) quit:name=""
			continue:$data(queued(name))
			do pEvidence.queue.%Push(##class(BlastRadius.Evidence.Traffic).QueueDepth(name))
		}
		// Names the production does not have leave the gate nothing to check, and nothing checked must not read as safe.
		if (items.%Size()>0),(hosts=0) {
			do reasons.%Push("None of the items the agent named is in this production: "_items.%ToJSON())
			set floor="HOLD"
		}
	}
	// A traffic check that failed is not a check. Nothing found and nothing looked at must not read the same.
	set it=pEvidence.traffic.%GetIterator()
	while it.%GetNext(.k,.t) {
		if t.error'="" {
			do reasons.%Push("The traffic check for "_t.item_" failed: "_t.error)
			set floor="HOLD"
		}
	}

	// Rule 2: every sender still active but declared nowhere has to be named by the requester or confirmed by its owner.
	if $isobject(pEvidence.traffic) {
		set it=pEvidence.traffic.%GetIterator()
		while it.%GetNext(.k,.t) {
			set un=t."active_senders_not_in_configuration"
			continue:'$isobject(un)
			set ui=un.%GetIterator()
			while ui.%GetNext(.uk,.sender) {
				set key="sender:"_sender
				// Each sender is one question, however many items it shows up on.
				continue:$data(askedSender(key))
				set askedSender(key)=""
				set detail=..SenderDetail(t,sender)
				continue:$data(refused(key))
				continue:$get(answers(key))="Confirm"
				continue:..AccountsFor(pRequestText,sender)
				do reasons.%Push(sender_" sends to "_t.item_" ("_detail_"), and nothing declares that link.")
				do tasks.%Push({"key":(key),"item":(sender),"reason":("Your feed "_sender_" still sends to "_t.item_" ("_detail_"). This change would retire that route. Can it move?")})
				set floor="HOLD"
			}
		}
	}

	// Rule 3: every field a shadow-run changed must be marked intended by the agent, or accepted by an owner.
	set class=pDecision."diff_classification"
	if $isobject(pEvidence.shadow) {
		set it=pEvidence.shadow.%GetIterator()
		while it.%GetNext(.k,.run) {
			if run.error'="" {
				do reasons.%Push("A shadow-run failed: "_run.error)
				set floor="HOLD"
				continue
			}
			if +run."messages_failed">0 {
				do reasons.%Push(run."messages_failed"_" stored messages failed in the shadow-run for "_run.item_".")
				set floor="HOLD"
			}
			set di=run."field_differences"
			continue:'$isobject(di)
			set fi=di.%GetIterator()
			while fi.%GetNext(.fk,.d) {
				set field=d.field
				set label=$select($isobject(class):class.%Get(field),1:"")
				continue:$zconvert(label,"L")="intended"
				set key="diff:"_field
				// Every run counts, so a later run cannot hide what an earlier one found. Each field is one question.
				continue:$data(asked(key))
				set asked(key)=""
				continue:$data(refused(key))
				continue:$get(answers(key))="Confirm"
				do reasons.%Push("Shadow-run: "_d.messages_" of "_run."messages_processed"_" stored messages "_$select(d.kind="lost":"lose",d.kind="added":"gain",1:"change")_" field "_field_", and nothing says that is intended.")
				do tasks.%Push({"key":(key),"item":(run.item),"reason":("Shadow-run with "_run.candidate_": "_d.messages_" of "_run."messages_processed"_" stored messages "_$select(d.kind="lost":"lose",d.kind="added":"gain",1:"change")_" field "_field_". Is that acceptable?")})
				set floor="HOLD"
			}
		}
	}

	// Rule 4: each router the decision names that transforms live traffic needs a shadow-run of its own on stored messages.
	// A run counts when it processed messages, its current transform is the one the router's rule uses now, and its
	// candidate is the transform of a router in this production or one the request names. A run whose candidate is a
	// router's transform also covers that router: it tested that transform on the traffic about to move there.
	if $isobject(items),$isobject(pEvidence.traffic) {
		if $isobject(pEvidence.shadow) {
			set it=pEvidence.shadow.%GetIterator()
			while it.%GetNext(.k,.run) {
				continue:'..ValidRun(run,pRequestText)
				set covered(run.item)=""
				set cov=..RoutersUsing(run.candidate)
				set ci=cov.%GetIterator()
				while ci.%GetNext(.ck,.router) { set covered(router)="" }
			}
		}
		set it=pEvidence.traffic.%GetIterator()
		while it.%GetNext(.k,.t) { if $isobject(t."senders_seen"),t."senders_seen".%Size()>0 { set busy(t.item)="" } }
		set it=items.%GetIterator()
		while it.%GetNext(.k,.name) {
			continue:'$data(busy(name))
			continue:$data(covered(name))
			continue:$data(said(name))
			set said(name)=""
			if ##class(BlastRadius.Evidence.Wiring).TransformsOf(name).transforms.%Size()>0 {
				do reasons.%Push(name_" transforms live traffic, and no shadow-run was done on stored messages.")
				set floor="HOLD"
			}
		}
	}

	// Rule 5: messages still queued on what is being changed have to drain first.
	if ..Rank(floor)<..Rank("APPLY-AFTER-DRAIN"),$isobject(pEvidence.queue),$isobject(items) {
		set it=pEvidence.queue.%GetIterator()
		while it.%GetNext(.k,.q) {
			continue:'$data(touched(q.item))
			if +q.queued>0 {
				do reasons.%Push(q.queued_" messages are still queued on "_q.item_".")
				set floor="APPLY-AFTER-DRAIN"
			}
		}
	}
	quit ..Result(floor,proposed,reasons,tasks)
}

ClassMethod Result(pFloor As %String, pProposed As %String, pReasons As %DynamicArray, pTasks As %DynamicArray) As %DynamicObject
{
	set final=$select(..Rank(pProposed)>..Rank(pFloor):pProposed,1:pFloor)
	quit {"verdict":(final),"floor":(pFloor),"proposed":(pProposed),"reasons":(pReasons),"tasks":(pTasks)}
}

/// True when the text names pName as a whole word, in any case. "Retire LIS-OLD" does not name a sender called LIS.
ClassMethod Names(pText As %String, pName As %String) As %Boolean
{
	set text=$zconvert(pText,"L"), name=$zconvert(pName,"L"), len=$length(name)
	set word="abcdefghijklmnopqrstuvwxyz0123456789-_"
	set from=0
	for {
		set from=$find(text,name,from) quit:from=0
		// A dot is part of a name like LAB-OLD.Router, and the end of a sentence otherwise.
		set before=$extract(text,from-len-1) set:before="." before=$extract(text,from-len-2)
		set after=$extract(text,from) set:after="." after=$extract(text,from+1)
		quit:((before="")||(word'[before))&&((after="")||(word'[after))
	}
	quit from>0
}

/// What the gate looks at on its own. pLookAt: traffic is checked for the hosts the decision names, the hosts the request names
/// (whole name, or the part before the dot, as "LAB-OLD" for LAB-OLD.Router), and the routers configured in front of all of them.
/// pTouched: the queue rule covers what the decision or the request names, not the routers in front.
ClassMethod Scope(pItems As %DynamicArray, pText As %String, Output pLookAt, Output pTouched)
{
	kill pLookAt, pTouched
	set sc=##class(BlastRadius.Evidence.Wiring).Items(.all)
	set it=pItems.%GetIterator()
	while it.%GetNext(.k,.name) { if $data(all(name)) { set pTouched(name)="" } }
	set name=""
	for {
		set name=$order(all(name)) quit:name=""
		set prefix=$piece(name,".",1)
		if ..Names(pText,name)||((prefix'=name)&&($length(prefix)>=3)&&..Names(pText,prefix)) { set pTouched(name)="" }
	}
	merge pLookAt=pTouched
	set name=""
	for {
		set name=$order(pTouched(name)) quit:name=""
		set links=##class(BlastRadius.Evidence.Wiring).Links(name)
		continue:'$isobject(links."configured_senders")
		set si=links."configured_senders".%GetIterator()
		while si.%GetNext(.sk,.row) {
			continue:'$data(all(row.sender))
			if ##class(BlastRadius.Evidence.Wiring).TransformsOf(row.sender).rule'="" { set pLookAt(row.sender)="" }
		}
	}
}

/// A shadow-run that tested something: it processed messages, its current transform is the one the router's rule uses,
/// and its candidate is different and is either a transform some router uses or one the request names.
ClassMethod ValidRun(pRun As %DynamicObject, pText As %String) As %Boolean
{
	quit:pRun.error'="" 0
	quit:+pRun."messages_processed"<=0 0
	quit:(pRun.current="")||(pRun.candidate="")||(pRun.current=pRun.candidate) 0
	set mine=##class(BlastRadius.Evidence.Wiring).TransformsOf(pRun.item).transforms, ok=0
	set it=mine.%GetIterator()
	while it.%GetNext(.k,.t) { set:t=pRun.current ok=1 }
	quit:'ok 0
	quit:..RoutersUsing(pRun.candidate).%Size()>0 1
	quit ..Names(pText,pRun.candidate)||..Names(pText,$piece(pRun.candidate,".",$length(pRun.candidate,".")))
}

/// The hosts whose routing rule uses pTransform.
ClassMethod RoutersUsing(pTransform As %String) As %DynamicArray
{
	set out=[]
	quit:pTransform="" out
	set sc=##class(BlastRadius.Evidence.Wiring).Items(.all)
	set name=""
	for {
		set name=$order(all(name)) quit:name=""
		set it=##class(BlastRadius.Evidence.Wiring).TransformsOf(name).transforms.%GetIterator()
		while it.%GetNext(.k,.t) { if t=pTransform { do out.%Push(name) quit } }
	}
	quit out
}

/// True when a sentence of the request names pName and commits to something for it, as in "the owner of annex-7 will re-point it"
/// or "Retire LAB-OLD, annex-7 too". A mention alone does not count: "I have no idea who annex-7 is", "do not break annex-7",
/// "check whether annex-7 still uses it". The owner is asked in those cases.
ClassMethod AccountsFor(pText As %String, pName As %String) As %Boolean
{
	set text=$zconvert($translate(pText,$char(10,13),"  "),"L")
	for sep="; ","! ","? " { set text=$replace(text,sep,". ") }
	set commit=$listbuild("retire","remove","decommission","shut down","turn off","re-point","repoint","will move","is moving","moves","migrat","switch","take over","takes over","will send")
	set deny=$listbuild("no idea","not sure","don't know","do not","don't","never","whether","check if","except","still","not yet","unless","unknown")
	for i=1:1:$length(text,". ") {
		set s=$piece(text,". ",i)
		continue:'..Names(s,pName)
		set yes=0, no=0
		for j=1:1:$listlength(commit) { set:s[$list(commit,j) yes=1 }
		for j=1:1:$listlength(deny) { set:s[$list(deny,j) no=1 }
		quit:yes&&'no
	}
	quit $get(yes)&&'$get(no)
}

/// Rules and transforms are named too; only hosts have traffic.
ClassMethod IsHost(pName As %String) As %Boolean
{
	set sc=##class(BlastRadius.Evidence.Wiring).Items(.items)
	quit $data(items(pName))>0
}

ClassMethod SenderDetail(pTraffic As %DynamicObject, pSender As %String) As %String
{
	set it=pTraffic."senders_seen".%GetIterator()
	while it.%GetNext(.k,.row) {
		if row.sender=pSender quit
	}
	quit:'$isobject($get(row)) ""
	quit row.messages_" messages in "_pTraffic."window_days"_" days, "_row.pattern
}

}
