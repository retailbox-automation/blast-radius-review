/// The agent's tools. All are read-only except ApplyChange, which exists so the refusal can be seen.
/// Each result is kept as evidence for the code gate, in process-private globals, so the gate reads the tool results and not the agent's account of them.
Class BlastRadius.Agent.Tools Extends %AI.Tool
{

/// Find production items by words from the request, such as "LAB-OLD" or "billing". Pass an empty string to list every item. Returns name, class, category, enabled flag, comment and owner.
ClassMethod FindItems(words As %String = "") As %String
{
	quit ##class(BlastRadius.Agent.EvidenceLog).Keep("items",##class(BlastRadius.Evidence.Wiring).Find(words))
}

/// What the production declares for one item, from settings, routing rules and literal targets in code: which items are declared to send to it, and which targets it is declared to send to. This is everything the production diagram and Interface Maps can show.
ClassMethod ConfiguredLinks(item As %String) As %String
{
	quit ##class(BlastRadius.Agent.EvidenceLog).Keep("configured",##class(BlastRadius.Evidence.Wiring).Links(item))
}

/// What really happened in the message headers for one item over the last N days, 30 at least: every sender with count, last seen, how many days ago, usual schedule, whether a setting declares the link, and whether it is still active. Lists active senders that no setting declares.
ClassMethod TrafficLinks(item As %String, days As %Integer = 30) As %String
{
	set days=$select(+days<30:30,1:+days)
	try { set r=##class(BlastRadius.Evidence.Traffic).Links(item,days) } catch ex { set r={"item":(item),"window_days":(days),"error":(ex.DisplayString())} }
	quit ##class(BlastRadius.Agent.EvidenceLog).Keep("traffic",r)
}

/// How many messages are waiting in an item's queue right now.
ClassMethod QueueDepth(item As %String) As %String
{
	quit ##class(BlastRadius.Agent.EvidenceLog).Keep("queue",##class(BlastRadius.Evidence.Traffic).QueueDepth(item))
}

/// Which data transforms a routing item's rule uses.
ClassMethod TransformsOf(item As %String) As %String
{
	quit ##class(BlastRadius.Agent.EvidenceLog).Keep("transforms",##class(BlastRadius.Evidence.Wiring).TransformsOf(item))
}

/// All data transforms in this namespace, with their descriptions. Use this to find a candidate transform.
ClassMethod ListTransforms() As %String
{
	quit ##class(BlastRadius.Evidence.Wiring).ListTransforms().%ToJSON()
}

/// Run the current and the candidate transform over the newest stored messages sent to an item, and compare the two outputs field by field. Nothing is saved or sent. Returns how many messages changed and, for each field, how many messages and which senders.
ClassMethod ShadowRun(item As %String, currentTransform As %String, candidateTransform As %String) As %String
{
	try { set r=##class(BlastRadius.Evidence.Shadow).Run(item,currentTransform,candidateTransform) } catch ex { set r={"item":(item),"candidate":(candidateTransform),"error":(ex.DisplayString())} }
	quit ##class(BlastRadius.Agent.EvidenceLog).Keep("shadow",r)
}

/// The named owner of a production item, from its Business Partner record.
ClassMethod OwnerOf(item As %String) As %String
{
	quit ##class(BlastRadius.Agent.EvidenceLog).Keep("owners",##class(BlastRadius.Evidence.Wiring).OwnerOf(item))
}

/// Record your decision. Call once, last. verdict is APPLY, APPLY-AFTER-DRAIN, CANARY-FIRST or HOLD. summary is at most three plain sentences. items is a comma-separated list of the production items this change touches. diffClassification is a JSON object mapping each shadow-run field to "intended" or "unintended", such as {"MSH-5":"intended","ORC-12":"unintended"}; use {} if there was no shadow-run.
ClassMethod SubmitDecision(verdict As %String, summary As %String, items As %String, diffClassification As %String = "{}") As %String
{
	set d={"verdict":(verdict),"summary":(summary)}
	set list=[]
	for i=1:1:$length(items,",") {
		set name=$zstrip($piece(items,",",i),"<>W")
		if name'="" do list.%Push(name)
	}
	do d.%Set("items",list)
	try { set c={}.%FromJSON(diffClassification) } catch { set c={} }
	do d.%Set("diff_classification",c)
	do ##class(BlastRadius.Agent.EvidenceLog).Keep("decision",d)
	quit "Decision recorded."
}

/// Apply the change to the production right now.
ClassMethod ApplyChange(item As %String) As %String
{
	// Unreachable while the Authorization policy is in force. A test proves it stays that way.
	set ^BlastRadius.ApplyAttempts($increment(^BlastRadius.ApplyAttempts))=item
	quit "applied"
}

}
