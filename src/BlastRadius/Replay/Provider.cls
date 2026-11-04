/// Speaks the OpenAI chat-completions protocol and answers from recordings of real runs.
/// To AI Hub this is just another provider: the agent loop, policies, audit and tools all run for real.
/// Only the model's words are played back, so a judge needs no key and the same requests give the same review.
Class BlastRadius.Replay.Provider Extends %CSP.REST
{

Parameter HandleCorsRequest = 0;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/v1/chat/completions" Method="POST" Call="Complete" />
<Route Url="/chat/completions" Method="POST" Call="Complete" />
<Route Url="/v1/models" Method="GET" Call="Models" />
</Routes>
}

ClassMethod Models() As %Status
{
	set %response.ContentType="application/json"
	write {"object":"list","data":[{"id":"replay","object":"model"}]}.%ToJSON()
	quit $$$OK
}

ClassMethod Complete() As %Status
{
	set %response.ContentType="application/json"
	try {
		set body={}.%FromJSON(%request.Content)
		set messages=body.messages
		set first="", step=0, system=""
		set it=messages.%GetIterator()
		while it.%GetNext(.k,.m) {
			if (m.role="user"),(first="") set first=..ContentText(m.content)
			if m.role="assistant" set step=step+1
			if (m.role="system"),(system="") set system=..ContentText(m.content)
		}
		// Which instructions actually reached the model, so a test can compare them with the trace.
		set ^BlastRadius.ReplaySeen("prompt_version")=##class(BlastRadius.Operation.Agent).PromptVersion(system)
		set key=##class(BlastRadius.Replay.Recorder).KeyFromPrompt(first)
		set fixture=##class(BlastRadius.Replay.Recorder).Load(key)
		if '$isobject(fixture) set fixture=..NoRecording()
		set steps=fixture.steps
		if step>=steps.%Size() {
			set out={"role":"assistant","content":"Done."}, usage={"prompt_tokens":0,"completion_tokens":0}
		} else {
			set row=steps.%Get(step), out=row.message, usage=row.usage
		}
		set finish=$select($isobject(out."tool_calls")&&(out."tool_calls".%Size()>0):"tool_calls",1:"stop")
		set usage."total_tokens"=usage."prompt_tokens"+usage."completion_tokens"
		set resp={"id":("replay-"_key_"-"_step),"object":"chat.completion","created":($zdatetime($ztimestamp,-2)),"model":(fixture.model),"choices":[{"index":0,"message":(out),"finish_reason":(finish)}],"usage":(usage)}
		write resp.%ToJSON()
	} catch ex {
		set %response.Status="500 Internal Server Error"
		write {"error":{"message":(ex.DisplayString()),"type":"replay_error"}}.%ToJSON()
	}
	quit $$$OK
}

/// A message's content can be a string or a list of parts.
ClassMethod ContentText(pContent) As %String
{
	quit:'$isobject(pContent) pContent
	set text="", it=pContent.%GetIterator()
	while it.%GetNext(.k,.part) { if $isobject(part) { set text=text_part.text } else { set text=text_part } }
	quit text
}

/// What a request without a recording gets: an honest hold that says how to run it for real.
ClassMethod NoRecording() As %DynamicObject
{
	set args={"verdict":"HOLD","summary":"Replay mode only knows the recorded requests, and this text is not one of them. Pick a preset, or set BR_LLM_MODE=live with a model of your own to review any request.","items":"","diffClassification":"{}"}
	set call={"id":"replay_none","type":"function","function":{"name":"SubmitDecision","arguments":(args.%ToJSON())}}
	quit {"model":"replay (no recording)","steps":[{"message":{"role":"assistant","content":null,"tool_calls":[(call)]},"usage":{"prompt_tokens":0,"completion_tokens":0}}]}
}

}
