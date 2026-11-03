/// Turns token counts into money for the decision card. Local models cost nothing per call.
/// Set BR_PRICE_IN and BR_PRICE_OUT (US dollars per million tokens) to price the model you run.
Class BlastRadius.Agent.Pricing Extends %RegisteredObject
{

/// Returns "" when the price of the model is not known, because a made-up number would be worse than none.
ClassMethod Cost(pModel As %String, pPromptTokens As %Integer, pCompletionTokens As %Integer) As %String
{
	set in=$system.Util.GetEnviron("BR_PRICE_IN"), out=$system.Util.GetEnviron("BR_PRICE_OUT")
	if (in'=""),(out'="") quit $fnumber((pPromptTokens*in+(pCompletionTokens*out))/1000000,"",6)
	set m=$zconvert(pModel,"L")
	if (m["gemma")||(m["granite")||(m["ollama") quit "0.000000"
	quit ""
}

}
