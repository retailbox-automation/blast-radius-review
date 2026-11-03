/// The Annex 7 clinic's weekly batch of standing orders, written years ago.
/// Its target comes from a lookup table at run time. No setting names it, and no literal in the code does,
/// so the production diagram and Interface Maps cannot show this link. Only the message headers can.
Class DemoHospital.Feed.Annex7Batch Extends Ens.BusinessService
{

Parameter ADAPTER;

Method OnProcessInput(pInput As EnsLib.HL7.Message, Output pOutput As %RegisteredObject) As %Status
{
	set target=##class(Ens.Util.LookupTable).%GetValue("Annex7Routing","standing-orders")
	quit ..SendRequestAsync(target,pInput)
}

}
