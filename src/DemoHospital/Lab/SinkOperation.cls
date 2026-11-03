/// Stands in for a downstream system. It accepts the message and does nothing else.
Class DemoHospital.Lab.SinkOperation Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

Method OnMessage(pRequest As %Persistent, Output pResponse As Ens.Response) As %Status
{
	quit $$$OK
}

}
