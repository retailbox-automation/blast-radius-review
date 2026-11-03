Include Ensemble

/// Saves a live run as a recording, and finds recordings again. Set BR_RECORD=1 next to BR_LLM_MODE=live to record.
Class BlastRadius.Replay.Recorder Extends %RegisteredObject
{

ClassMethod Dir() As %String
{
	quit ##class(BlastRadius.Install).Home()_"replay/"
}

/// A recording is found by the request text, the round, and what the owners decided. Comments do not change the key.
ClassMethod Key(pText As %String, pRound As %Integer, pAnswers As %String = "") As %String
{
	set norm=$zconvert($zstrip(pText,"<=>W"),"L")_"|"_pRound
	if pAnswers'="" {
		set arr=[].%FromJSON(pAnswers), it=arr.%GetIterator()
		while it.%GetNext(.k,.a) { set list(a.key)=a.action }
		set k="" for { set k=$order(list(k),1,v) quit:k=""  set norm=norm_"|"_k_"="_v }
	}
	quit $extract(##class(%xsd.hexBinary).LogicalToXSD($system.Encryption.MD5Hash($zconvert(norm,"O","UTF8"))),1,16)
}

/// The same key, worked out from the prompt the agent operation builds.
ClassMethod KeyFromPrompt(pPrompt As %String) As %String
{
	set nl=$char(10)
	set text=$piece($piece(pPrompt,"CHANGE REQUEST:"_nl,2),nl_"END OF REQUEST",1)
	set round=+$piece($piece(pPrompt,"ROUND: ",2),nl,1)
	set answers=$piece($piece(pPrompt,"OWNER ANSWERS:"_nl,2),nl_"END OF ANSWERS",1)
	quit ..Key(text,round,answers)
}

ClassMethod Load(pKey As %String) As %DynamicObject
{
	set file=..Dir()_pKey_".json"
	quit:'##class(%File).Exists(file) ""
	set s=##class(%Stream.FileCharacter).%New()
	set s.TranslateTable="UTF8"
	do s.LinkToFile(file)
	quit {}.%FromJSON(s)
}

/// The model the recording came from, for the card.
ClassMethod RecordedModel(pText As %String, pRound As %Integer, pAnswers As %String = "") As %String
{
	set f=..Load(..Key(pText,pRound,pAnswers))
	quit $select($isobject(f):f.model,1:"no recording")
}

/// True when the current review ran to its end and the agent decided.
ClassMethod Finished() As %Boolean
{
	quit ('$get(^||BR("failed")))&&($data(^||BR("ev","decision"))>0)
}

ClassMethod MaybeRecord(pRequest As BlastRadius.Msg.ReviewRequest, pSession As %AI.Agent.Session, pResponse As BlastRadius.Msg.ReviewResult)
{
	quit:$system.Util.GetEnviron("BR_RECORD")'="1"
	if '..Finished() {
		$$$LOGWARNING("Not recorded: the review failed or never decided, so any earlier recording stays.")
		quit
	}
	try {
		set ctx=pSession.GetContext()
		set stats=pSession.GetStats()
		set turns=+stats."total_interactions" set:turns<1 turns=1
		set up=stats."total_prompt_tokens"\turns, down=stats."total_completion_tokens"\turns
		set steps=[]
		set it=ctx.%GetIterator()
		while it.%GetNext(.k,.m) {
			continue:m.role'="assistant"
			set out={"role":"assistant","content":(m.content)}
			if $isobject(m."tool_calls") {
				set calls=[], ci=m."tool_calls".%GetIterator()
				while ci.%GetNext(.ck,.c) {
					do calls.%Push({"id":(c.id),"type":"function","function":{"name":(c.name),"arguments":(c.arguments)}})
				}
				do out.%Set("tool_calls",calls)
			}
			do steps.%Push({"message":(out),"usage":{"prompt_tokens":(up),"completion_tokens":(down)}})
		}
		set key=..Key(pRequest.Text,pRequest.Round,pRequest.OwnerAnswers)
		set rec={"request":(pRequest.Text),"round":(pRequest.Round),"owner_answers":(pRequest.OwnerAnswers),"model":(pResponse.Model),"recorded_at":($zdatetime($ztimestamp,3)),"total_prompt_tokens":(stats."total_prompt_tokens"),"total_completion_tokens":(stats."total_completion_tokens"),"verdict":(pResponse.AgentVerdict),"steps":(steps)}
		set s=##class(%Stream.FileCharacter).%New()
		set s.TranslateTable="UTF8"
		$$$ThrowOnError(s.LinkToFile(..Dir()_key_".json"))
		set formatter=##class(%JSON.Formatter).%New()
		do formatter.FormatToString(rec,.pretty)
		do s.Write(pretty)
		$$$ThrowOnError(s.%Save())
		$$$LOGINFO("Recorded "_key_" with "_steps.%Size()_" steps")
	} catch ex {
		$$$LOGWARNING("Recording failed: "_ex.DisplayString())
	}
}

}
