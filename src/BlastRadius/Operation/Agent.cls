/// Hosts the AI Hub agent through the stock outbound adapter, runs the code gate on its proposal, and records the result.
Class BlastRadius.Operation.Agent Extends Ens.BusinessOperation
{

Parameter ADAPTER = "BlastRadius.Agent.Adapter";

Parameter INVOCATION = "Queue";

Property Adapter As BlastRadius.Agent.Adapter;

Method OnMessage(pRequest As BlastRadius.Msg.ReviewRequest, Output pResponse As BlastRadius.Msg.ReviewResult) As %Status
{
	set sc=$$$OK
	try {
		kill ^||BR
		set ^||BR("cr")=pRequest.CRId, ^||BR("round")=pRequest.Round
		do ..MarkInReview(pRequest.CRId)
		set t0=$zh
		set session=..Adapter.Agent.CreateSession(..Adapter.SessionConfig)
		set scChat=..Adapter.SendChat(..Prompt(pRequest),.llm,session)
		// A model that stopped without deciding gets one nudge. The gate holds if it still does not decide.
		if $$$ISOK(scChat),'$data(^||BR("ev","decision")) {
			set scChat=..Adapter.SendChat("You have not called SubmitDecision yet. Call it now, as your last action.",.llm,session)
		}
		set ^||BR("failed")=$$$ISERR(scChat)
		set elapsed=($zh-t0)*1000\1
		set evidence=##class(BlastRadius.Agent.EvidenceLog).CollectEvidence()
		set decision=""
		if $isobject(evidence.decision) set decision=evidence.decision.%Get(evidence.decision.%Size()-1)
		set answers=""
		if pRequest.OwnerAnswers'="" set answers=[].%FromJSON(pRequest.OwnerAnswers)
		set gate=##class(BlastRadius.Gate.Floor).Decide(evidence,decision,pRequest.Text,answers)
		if $$$ISERR(scChat) { do gate.reasons.%Push("The agent failed: "_$system.Status.GetOneErrorText(scChat)) set gate.verdict="HOLD" }
		set stats=session.GetStats()

		set pResponse=##class(BlastRadius.Msg.ReviewResult).%New()
		set pResponse.CRId=pRequest.CRId, pResponse.Round=pRequest.Round
		set pResponse.AgentVerdict=gate.proposed, pResponse.FinalVerdict=gate.verdict
		set pResponse.Summary=$select($isobject(decision):decision.summary,1:"")
		set pResponse.GateReasons=gate.reasons.%ToJSON()
		set pResponse.Mode=##class(BlastRadius.Agent.Adapter).Mode()
		set pResponse.Model=$select(pResponse.Mode="replay":##class(BlastRadius.Replay.Recorder).RecordedModel(pRequest.Text,pRequest.Round,pRequest.OwnerAnswers),1:..Adapter.Model)
		set pResponse.PromptTokens=stats."total_prompt_tokens", pResponse.CompletionTokens=stats."total_completion_tokens"
		set pResponse.ToolCalls=stats."total_tool_calls", pResponse.DurationMs=elapsed
		// Owner tasks only exist on a hold, and only in the first round.
		if (gate.verdict="HOLD"),(pRequest.Round=1) { do ..BuildTasks(gate,pResponse) }

		do ..SendToolTrace(pRequest)
		do ..Save(pRequest,pResponse,evidence,gate,session)
	} catch ex { set sc=ex.AsStatus() }
	quit sc
}

Method MarkInReview(pCRId As %String)
{
	set r=##class(BlastRadius.Data.Review).Find(pCRId)
	quit:'$isobject(r)
	set r.Status="IN-REVIEW"
	do r.%Save()
}

/// The user message. The markers let the replay provider recognise a recorded request.
Method Prompt(pRequest As BlastRadius.Msg.ReviewRequest) As %String
{
	set p="Review this change request.",nl=$char(10)
	set p=p_nl_"CHANGE REQUEST:"_nl_pRequest.Text_nl_"END OF REQUEST"_nl_"ROUND: "_pRequest.Round
	if pRequest.OwnerAnswers'="" {
		set p=p_nl_"OWNER ANSWERS:"_nl_pRequest.OwnerAnswers_nl_"END OF ANSWERS"
	}
	quit p
}

Method BuildTasks(pGate As %DynamicObject, pResponse As BlastRadius.Msg.ReviewResult)
{
	set it=pGate.tasks.%GetIterator()
	while it.%GetNext(.k,.t) {
		set owner=##class(BlastRadius.Evidence.Wiring).OwnerOf(t.item)
		set role=owner."workflow_role"
		set subject=pResponse.CRId_": "_$select(t.key["sender:":"confirm "_t.item,1:"review "_$piece(t.key,":",2))
		do pResponse.Owners.Insert(role_"|"_t.key_"|"_subject_"|"_$translate(t.reason,"|","/"))
	}
}

/// One lightweight message per tool call, so the agent's work shows up in Visual Trace next to everything else.
Method SendToolTrace(pRequest As BlastRadius.Msg.ReviewRequest)
{
	set n=""
	for {
		set n=$order(^||BR("calls",n),1,row) quit:n=""
		set rec=##class(BlastRadius.Msg.ToolCallRecord).%New()
		set rec.CRId=pRequest.CRId, rec.Round=pRequest.Round
		set rec.Tool=$list(row,1), rec.Arguments=$list(row,2), rec.Outcome=$list(row,3), rec.Result=$list(row,4), rec.DurationMs=$list(row,5)
		do ..SendRequestAsync("BlastRadius.ToolLedger",rec,0)
	}
}

Method Save(pRequest As BlastRadius.Msg.ReviewRequest, pResponse As BlastRadius.Msg.ReviewResult, pEvidence As %DynamicObject, pGate As %DynamicObject, pSession As %AI.Agent.Session)
{
	set r=##class(BlastRadius.Data.Review).Find(pRequest.CRId)
	quit:'$isobject(r)
	set r.Round=pRequest.Round
	set r.Verdict=pResponse.FinalVerdict, r.AgentVerdict=pResponse.AgentVerdict
	set r.Summary=pResponse.Summary, r.GateReasons=pResponse.GateReasons
	set r.Status=$select(pResponse.Owners.Count()>0:"WAITING-OWNERS",1:"DONE")
	set r.SessionId=..%SessionId
	set r.Model=pResponse.Model, r.Mode=pResponse.Mode
	set r.PromptTokens=r.PromptTokens+pResponse.PromptTokens
	set r.CompletionTokens=r.CompletionTokens+pResponse.CompletionTokens
	set r.ToolCalls=r.ToolCalls+pResponse.ToolCalls
	set r.DurationMs=r.DurationMs+pResponse.DurationMs
	set r.UpdatedAt=$zdatetime($ztimestamp,3)
	do r.Evidence.Clear()
	do r.Evidence.Write(pEvidence.%ToJSON())
	set rounds=$select(r.Rounds.Size>0:[].%FromJSON(r.Rounds.Read()),1:[])
	do rounds.%Push({"round":(pRequest.Round),"agent_verdict":(pResponse.AgentVerdict),"final_verdict":(pResponse.FinalVerdict),"summary":(pResponse.Summary),"gate_reasons":(pGate.reasons),"owner_answers":($select(pRequest.OwnerAnswers'="":[].%FromJSON(pRequest.OwnerAnswers),1:[])),"prompt_tokens":(pResponse.PromptTokens),"completion_tokens":(pResponse.CompletionTokens),"tool_calls":(pResponse.ToolCalls),"duration_ms":(pResponse.DurationMs)})
	do r.Rounds.Clear()
	do r.Rounds.Write(rounds.%ToJSON())
	do r.%Save()
	do ##class(BlastRadius.Replay.Recorder).MaybeRecord(pRequest,pSession,pResponse)
}

}
