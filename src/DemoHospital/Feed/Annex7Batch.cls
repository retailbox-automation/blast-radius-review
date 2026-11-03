/// The Annex 7 clinic's weekly batch of standing orders, written years ago.
/// Nothing in the production settings mentions its target: the name is hard-coded below.
/// This is how a real production ends up with a consumer the configuration cannot show you.
Class DemoHospital.Feed.Annex7Batch Extends Ens.BusinessService
{

Parameter ADAPTER;

Method OnProcessInput(pInput As EnsLib.HL7.Message, Output pOutput As %RegisteredObject) As %Status
{
	quit ..SendRequestAsync("LAB-OLD.Router", pInput)
}

}
