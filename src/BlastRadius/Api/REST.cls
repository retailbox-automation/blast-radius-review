/// HTTP API behind the decision card. POST turns a request into a production message; GET reads the result.
Class BlastRadius.Api.REST Extends %CSP.REST
{

Parameter CONTENTTYPE = "application/json";

Parameter CHARSET = "UTF-8";

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/health" Method="GET" Call="Health" />
<Route Url="/presets" Method="GET" Call="Presets" />
<Route Url="/change-requests" Method="POST" Call="Submit" />
<Route Url="/change-requests" Method="GET" Call="List" />
<Route Url="/change-requests/:id" Method="GET" Call="Get" />
<Route Url="/tasks/:id" Method="POST" Call="Answer" />
</Routes>
}

ClassMethod Health() As %Status
{
	do ##class(Ens.Director).GetProductionStatus(.name,.state)
	set ready=($get(^BlastRadius.Seed("done"))'="")&&(state=1)
	set res={"production":($get(name)),"mode":(##class(BlastRadius.Agent.Adapter).Mode()),"seeded_at":($get(^BlastRadius.Seed("done")))}
	do res.%Set("ready",ready,"boolean")
	write res.%ToJSON()
	quit $$$OK
}

/// The requests that have recordings, so replay mode works with one click.
ClassMethod Presets() As %Status
{
	write ##class(BlastRadius.Api.Presets).All().%ToJSON()
	quit $$$OK
}

ClassMethod Submit() As %Status
{
	set body={}.%FromJSON(%request.Content)
	set text=$zstrip(body.text,"<>W")
	if text="" {
		set %response.Status="400 Bad Request"
		write {"error":"text is required"}.%ToJSON()
		quit $$$OK
	}
	do ##class(Ens.Director).GetProductionStatus(.name,.state)
	if state'=1 {
		set %response.Status="503 Service Unavailable"
		write {"error":"The production is not running yet. It takes about a minute on first start."}.%ToJSON()
		quit $$$OK
	}
	set id="CR-"_$translate($justify($increment(^BlastRadius.CR),4)," ","0")
	set r=##class(BlastRadius.Data.Review).%New()
	set r.CRId=id, r.Text=text, r.Requester=body.requester, r.Supersedes=body.supersedes, r.Status="IN-REVIEW"
	$$$QuitOnError(r.%Save())
	set msg=##class(BlastRadius.Msg.ChangeRequest).%New()
	set msg.CRId=id, msg.Text=text, msg.Requester=body.requester, msg.Supersedes=body.supersedes
	$$$QuitOnError(##class(Ens.Director).CreateBusinessService("BlastRadius.ChangeRequests",.svc))
	$$$QuitOnError(svc.ProcessInput(msg,.out))
	set r.SessionId=+out.StringValue
	$$$QuitOnError(r.%Save())
	set %response.Status="202 Accepted"
	write {"id":(id),"status":"IN-REVIEW","session_id":(r.SessionId)}.%ToJSON()
	quit $$$OK
}

ClassMethod List() As %Status
{
	set out=[]
	set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT TOP 50 CRId,Text,Status,Verdict,UpdatedAt FROM BlastRadius_Data.Review ORDER BY ID DESC")
	while rs.%Next() { do out.%Push({"id":(rs.CRId),"text":(rs.Text),"status":(rs.Status),"verdict":(rs.Verdict),"updated_at":(rs.UpdatedAt)}) }
	write out.%ToJSON()
	quit $$$OK
}

ClassMethod Get(pId As %String) As %Status
{
	set r=##class(BlastRadius.Data.Review).Find(pId)
	if '$isobject(r) {
		set %response.Status="404 Not Found"
		write {"error":("No such change request: "_pId)}.%ToJSON()
		quit $$$OK
	}
	write ..Card(r).%ToJSON()
	quit $$$OK
}

/// Everything the decision card shows, in one object.
ClassMethod Card(r As BlastRadius.Data.Review) As %DynamicObject
{
	set ns=$zconvert($namespace,"L")
	set res={"id":(r.CRId),"text":(r.Text),"requester":(r.Requester),"supersedes":(r.Supersedes),"status":(r.Status),"verdict":(r.Verdict),"agent_verdict":(r.AgentVerdict),"summary":(r.Summary),"round":(r.Round),"model":(r.Model),"mode":(r.Mode),"prompt_tokens":(+r.PromptTokens),"completion_tokens":(+r.CompletionTokens),"tool_calls":(+r.ToolCalls),"duration_ms":(+r.DurationMs),"created_at":(r.CreatedAt),"updated_at":(r.UpdatedAt),"session_id":(+r.SessionId)}
	do res.%Set("cost_usd",##class(BlastRadius.Agent.Pricing).Cost(r.Model,r.PromptTokens,r.CompletionTokens))
	do res.%Set("gate_reasons",$select(r.GateReasons'="":[].%FromJSON(r.GateReasons),1:[]))
	do res.%Set("rounds",$select(r.Rounds.Size>0:[].%FromJSON(r.Rounds.Read()),1:[]))
	do res.%Set("evidence",$select(r.Evidence.Size>0:{}.%FromJSON(r.Evidence.Read(3000000)),1:{}))
	do res.%Set("tasks",..Tasks(r.CRId))
	do res.%Set("pulse",..PulseFor(res.evidence))
	do res.%Set("audit",..Audit(r.CRId))
	// On IRIS for Health the namespace's portal lives under /csp/healthshare, not /csp.
	set csp="/csp/healthshare/"_ns_"/"
	do res.%Set("links",{"visual_trace":(csp_"EnsPortal.VisualTrace.zen?SESSIONID="_r.SessionId),"message_viewer":(csp_"EnsPortal.MessageViewer.zen"),"workflow_inbox":(csp_"_DeepSee.UserPortal.Workflow.zen"),"production":(csp_"EnsPortal.ProductionConfig.zen?PRODUCTION=DemoHospital.Production")})
	quit res
}

ClassMethod Tasks(pCRId As %String) As %DynamicArray
{
	set out=[]
	set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT ID,%Subject s,%Message m,TaskStatus_RoleName r,TaskStatus_IsComplete c,%Action a,TaskStatus_AssignedTo u,TaskStatus_TimeCreated t FROM EnsLib_Workflow.TaskResponse WHERE %Subject %STARTSWITH ? ORDER BY ID",pCRId_":")
	while rs.%Next() {
		set row={"id":(rs.ID),"subject":(rs.s),"message":(rs.m),"role":(rs.r),"action":(rs.a),"assigned_to":(rs.u),"owner":(..OwnerForRole(rs.r))}
		try { do row.%Set("comment",##class(EnsLib.Workflow.TaskResponse).%OpenId(rs.ID).%FormValues.GetAt("Comment")) } catch {}
		do row.%Set("complete",rs.c,"boolean")
		do out.%Push(row)
	}
	quit out
}

/// Who a Workflow role reaches, from the lookup and the Business Partner record.
ClassMethod OwnerForRole(pRole As %String) As %String
{
	set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT KeyName FROM Ens_Util.LookupTable WHERE TableName='BlastRadiusOwners' AND DataValue=?",pRole)
	quit:'rs.%Next() "Integration lead"
	set partner=rs.KeyName
	set bp=##class(Ens.Config.BusinessPartner).%OpenId(partner)
	quit:'$isobject(bp) partner
	quit $select(bp.PrimaryContact.Name'="":bp.PrimaryContact.Name_", ",1:"")_partner
}

/// The strip under the map: the undeclared sender if there is one, otherwise the busiest sender still active.
ClassMethod PulseFor(pEvidence As %DynamicObject) As %DynamicObject
{
	quit:'$isobject(pEvidence.traffic) ""
	set best="", bestItem="", bestPattern="", bestCount=-1, alert=0
	set it=pEvidence.traffic.%GetIterator()
	while it.%GetNext(.k,.t) {
		continue:'$isobject(t."senders_seen")
		set si=t."senders_seen".%GetIterator()
		while si.%GetNext(.sk,.row) {
			continue:'row."still_active"
			set isAlert='row.configured
			if (isAlert>alert)||((isAlert=alert)&&(row.messages>bestCount)) {
				set best=row.sender, bestItem=t.item, bestPattern=row.pattern, bestCount=row.messages, alert=isAlert
			}
		}
	}
	quit:best="" ""
	set days=##class(BlastRadius.Evidence.Traffic).Pulse(best,bestItem)
	set list="", it=days.%GetIterator()
	while it.%GetNext(.k,.d) { set list=list_$select(list="":"",1:",")_d."days_ago" }
	set rhythm={}.%FromJSON(##class(BlastRadius.Evidence.Rhythm).NextExpected(list))
	quit {"sender":(best),"item":(bestItem),"pattern":(bestPattern),"window_days":30,"days":(days),"rhythm":(rhythm)}
}

ClassMethod Audit(pCRId As %String) As %DynamicArray
{
	set out=[]
	set rs=##class(BlastRadius.Evidence.Sql).Run("SELECT ReviewRound,LoggedAt,Outcome,Tool,Arguments,Detail,DurationMs FROM BlastRadius_Data.AuditEvent WHERE CRId=? ORDER BY ID",pCRId)
	while rs.%Next() { do out.%Push({"round":(rs.ReviewRound),"at":(rs.LoggedAt),"outcome":(rs.Outcome),"tool":(rs.Tool),"arguments":(rs.Arguments),"detail":(rs.Detail),"duration_ms":(+rs.DurationMs)}) }
	quit out
}

/// Answers a Workflow task, the same as the inbox does. The review then continues by itself.
ClassMethod Answer(pId As %String) As %Status
{
	set body={}.%FromJSON(%request.Content)
	set t=##class(EnsLib.Workflow.TaskResponse).%OpenId(pId)
	if '$isobject(t) {
		set %response.Status="404 Not Found"
		write {"error":("No such task: "_pId)}.%ToJSON()
		quit $$$OK
	}
	if t.%FormValues.Count()=0,body.comment'="" { do t.%FormValues.SetAt(body.comment,"Comment") }
	else { do t.%FormValues.SetAt(body.comment,"Comment") }
	$$$QuitOnError(t.%Save())
	$$$QuitOnError(t.CompleteTask(body.action))
	write {"id":(pId),"action":(body.action)}.%ToJSON()
	quit $$$OK
}

}
