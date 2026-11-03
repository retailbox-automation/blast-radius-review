/// Asks the agent to review a change request. Round 2 carries what the owners answered.
Class BlastRadius.Msg.ReviewRequest Extends Ens.Request
{

Property CRId As %String;

Property Text As %String(MAXLEN = "");

Property Round As %Integer [ InitialExpression = 1 ];

/// JSON array of {key, role, action, comment, user}.
Property OwnerAnswers As %String(MAXLEN = "");

Storage Default
{
<Data name="ReviewRequestDefaultData">
<Subscript>"ReviewRequest"</Subscript>
<Value name="1">
<Value>CRId</Value>
</Value>
<Value name="2">
<Value>Text</Value>
</Value>
<Value name="3">
<Value>Round</Value>
</Value>
<Value name="4">
<Value>OwnerAnswers</Value>
</Value>
</Data>
<DefaultData>ReviewRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
