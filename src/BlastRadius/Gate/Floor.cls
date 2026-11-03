/// The code half of "the agent proposes, code decides".
/// It reads what the tools actually returned, never the agent's prose, and works out the softest verdict the evidence allows.
/// The agent may be stricter than this floor. It can never be softer.
Class BlastRadius.Gate.Floor Extends %RegisteredObject
{

/// Mildest first.
Parameter ORDER = "APPLY,APPLY-AFTER-DRAIN,CANARY-FIRST,HOLD";

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

	// Rule 1: a review needs evidence for everything it names. If the agent skipped a check, the gate runs it itself and judges the result.
	set items=pDecision.items
	if '$isobject(items)||(items.%Size()=0) {
		do reasons.%Push("The agent named no production items.")
		set floor="HOLD"
	}
	if '$isobject(pEvidence.traffic) { do pEvidence.%Set("traffic",[]) }
	if '$isobject(pEvidence.queue) { do pEvidence.%Set("queue",[]) }
	set it=pEvidence.traffic.%GetIterator()
	while it.%GetNext(.k,.t) { set checked(t.item)="" }
	set it=pEvidence.queue.%GetIterator()
	while it.%GetNext(.k,.q) { set queued(q.item)="" }
	if $isobject(items) {
		set it=items.%GetIterator()
		while it.%GetNext(.k,.name) {
			continue:'..IsHost(name)
			if '$data(checked(name)) {
				try { set t=##class(BlastRadius.Evidence.Traffic).Links(name) } catch ex { set t={"item":(name),"window_days":30,"error":(ex.DisplayString())} }
				do pEvidence.traffic.%Push(t)
			}
			if '$data(queued(name)) { do pEvidence.queue.%Push(##class(BlastRadius.Evidence.Traffic).QueueDepth(name)) }
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
				set detail=..SenderDetail(t,sender)
				if $get(answers(key))="Reject" {
					do reasons.%Push("The owner of "_sender_" rejected this change.")
					set floor="HOLD"
					continue
				}
				continue:$get(answers(key))="Confirm"
				continue:pRequestText[sender
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
			set lastRun(run.item)=run
		}
		set item=""
		for {
			set item=$order(lastRun(item),1,run) quit:item=""
			if +run."messages_failed">0 {
				do reasons.%Push(run."messages_failed"_" stored messages failed in the shadow-run for "_item_".")
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
				if $get(answers(key))="Reject" {
					do reasons.%Push("An owner rejected the change to "_field_".")
					set floor="HOLD"
					continue
				}
				continue:$get(answers(key))="Confirm"
				do reasons.%Push("Shadow-run: "_d.messages_" of "_run."messages_processed"_" stored messages "_$select(d.kind="lost":"lose",d.kind="added":"gain",1:"change")_" field "_field_", and nothing says that is intended.")
				do tasks.%Push({"key":(key),"item":(item),"reason":("Shadow-run with "_run.candidate_": "_d.messages_" of "_run."messages_processed"_" stored messages "_$select(d.kind="lost":"lose",d.kind="added":"gain",1:"change")_" field "_field_". Is that acceptable?")})
				set floor="HOLD"
			}
		}
	}

	// Rule 4: a router that transforms live traffic cannot be changed without testing that on stored messages.
	if $isobject(items),$isobject(pEvidence.traffic) {
		set it=pEvidence.traffic.%GetIterator()
		while it.%GetNext(.k,.t) { if $isobject(t."senders_seen"),t."senders_seen".%Size()>0 { set busy(t.item)="" } }
		set it=items.%GetIterator()
		while it.%GetNext(.k,.name) {
			continue:'$data(busy(name))
			continue:$data(lastRun(name))
			if ##class(BlastRadius.Evidence.Wiring).TransformsOf(name).transforms.%Size()>0 {
				do reasons.%Push(name_" transforms live traffic, and no shadow-run was done on its stored messages.")
				set floor="HOLD"
			}
		}
	}

	// Rule 5: messages still queued on what is being changed have to drain first.
	if ..Rank(floor)<..Rank("APPLY-AFTER-DRAIN"),$isobject(pEvidence.queue),$isobject(items) {
		set it=items.%GetIterator()
		while it.%GetNext(.k,.name) { set touched(name)="" }
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
