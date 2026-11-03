/// A proposed change to the production, in the engineer's own words. It travels the production like any other message.
Class BlastRadius.Msg.ChangeRequest Extends Ens.Request
{

Property CRId As %String;

Property Text As %String(MAXLEN = "");

Property Requester As %String(MAXLEN = 200);

/// The change request this one replaces, if any.
Property Supersedes As %String;

Storage Default
{
<Data name="ChangeRequestDefaultData">
<Subscript>"ChangeRequest"</Subscript>
<Value name="1">
<Value>CRId</Value>
</Value>
<Value name="2">
<Value>Text</Value>
</Value>
<Value name="3">
<Value>Requester</Value>
</Value>
<Value name="4">
<Value>Supersedes</Value>
</Value>
</Data>
<DefaultData>ChangeRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
