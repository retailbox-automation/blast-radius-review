/// The stock AI Hub adapter, with its provider settings taken from environment variables.
/// BR_LLM_MODE=replay (the default) points the agent at recorded responses, so no key is needed and every tool still runs for real.
Class BlastRadius.Agent.Adapter Extends EnsLib.AI.Agent.OutboundAdapter
{

Parameter REPLAYURL = "http://127.0.0.1:52773/blastradius/replay/v1";

ClassMethod Mode() As %String
{
	set m=$zconvert($system.Util.GetEnviron("BR_LLM_MODE"),"L")
	quit $select(m="live":"live",1:"replay")
}

/// How long one review, and one model request inside it, may take. AI Hub stops a run after 300 seconds by default.
ClassMethod TimeoutSeconds() As %Integer
{
	set s=+$system.Util.GetEnviron("BR_LLM_TIMEOUT_S")
	quit $select(s>0:s,1:900)
}

Method OnBeforeAgentInit(ByRef agent As %AI.Agent) As %Status
{
	set config={}
	if ..Mode()="live" {
		set seconds=..TimeoutSeconds()
		do config.%Set("http_config",{"request_timeout_secs":(seconds)})
		set ..SessionConfigString={"timeout_ms":(seconds*1000)}.%ToJSON()
		set provider=$system.Util.GetEnviron("BR_LLM_PROVIDER")
		if provider="" set provider="openai"
		set key=$system.Util.GetEnviron("BR_LLM_API_KEY")
		if key="" set key="none"
		do config.%Set("api_key",key)
		set url=$system.Util.GetEnviron("BR_LLM_BASE_URL")
		if url'="" do config.%Set("base_url",url)
		set model=$system.Util.GetEnviron("BR_LLM_MODEL")
		if model="" quit $$$ERROR($$$GeneralError,"BR_LLM_MODE=live needs BR_LLM_MODEL. See the README.")
	} else {
		set provider="openai", model="replay"
		do config.%Set("api_key","replay")
		do config.%Set("base_url",..#REPLAYURL)
	}
	set ..ProviderName=provider
	set ..ProviderConfig=config.%ToJSON()
	set ..Model=model
	quit $$$OK
}

}
