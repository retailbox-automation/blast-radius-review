/// The current state of one change request, for the API and the decision card.
Class BlastRadius.Data.Review Extends %Persistent
{

Property CRId As %String [ Required ];

Property Text As %String(MAXLEN = "");

Property Requester As %String(MAXLEN = 200);

Property Supersedes As %String;

/// IN-REVIEW, WAITING-OWNERS or DONE.
Property Status As %String;

Property Verdict As %String;

Property AgentVerdict As %String;

Property Summary As %String(MAXLEN = "");

Property GateReasons As %String(MAXLEN = "");

/// JSON: what the tools actually returned, by tool. The gate reads this, never the agent's prose.
Property Evidence As %Stream.GlobalCharacter;

/// JSON array with one entry per finished round.
Property Rounds As %Stream.GlobalCharacter;

Property SessionId As %Integer;

Property Round As %Integer;

Property Model As %String(MAXLEN = 200);

Property Mode As %String;

Property PromptTokens As %Integer;

Property CompletionTokens As %Integer;

Property ToolCalls As %Integer;

Property DurationMs As %Integer;

Property CreatedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp,3)} ];

Property UpdatedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp,3)} ];

Index CRIdIndex On CRId [ Unique ];

ClassMethod Find(pCRId As %String) As BlastRadius.Data.Review
{
	quit ##class(BlastRadius.Data.Review).CRIdIndexOpen(pCRId)
}

Storage Default
{
<Data name="ReviewDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>CRId</Value>
</Value>
<Value name="3">
<Value>Text</Value>
</Value>
<Value name="4">
<Value>Requester</Value>
</Value>
<Value name="5">
<Value>Supersedes</Value>
</Value>
<Value name="6">
<Value>Status</Value>
</Value>
<Value name="7">
<Value>Verdict</Value>
</Value>
<Value name="8">
<Value>AgentVerdict</Value>
</Value>
<Value name="9">
<Value>Summary</Value>
</Value>
<Value name="10">
<Value>GateReasons</Value>
</Value>
<Value name="11">
<Value>Evidence</Value>
</Value>
<Value name="12">
<Value>Rounds</Value>
</Value>
<Value name="13">
<Value>SessionId</Value>
</Value>
<Value name="14">
<Value>Round</Value>
</Value>
<Value name="15">
<Value>Model</Value>
</Value>
<Value name="16">
<Value>Mode</Value>
</Value>
<Value name="17">
<Value>PromptTokens</Value>
</Value>
<Value name="18">
<Value>CompletionTokens</Value>
</Value>
<Value name="19">
<Value>ToolCalls</Value>
</Value>
<Value name="20">
<Value>DurationMs</Value>
</Value>
<Value name="21">
<Value>CreatedAt</Value>
</Value>
<Value name="22">
<Value>UpdatedAt</Value>
</Value>
</Data>
<DataLocation>^BlastRadius.Data.ReviewD</DataLocation>
<DefaultData>ReviewDefaultData</DefaultData>
<IdLocation>^BlastRadius.Data.ReviewD</IdLocation>
<IndexLocation>^BlastRadius.Data.ReviewI</IndexLocation>
<StreamLocation>^BlastRadius.Data.ReviewS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
