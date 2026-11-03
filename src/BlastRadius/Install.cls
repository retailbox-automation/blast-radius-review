/// Build-time and first-start setup.
Class BlastRadius.Install Extends %RegisteredObject
{

Parameter NS = "BLASTRADIUS";

Parameter PRODUCTION = "DemoHospital.Production";

/// Called from iris.script during docker build.
ClassMethod AtBuild() As %Status
{
	set sc=$$$OK
	try {
		$$$ThrowOnError(..WebApps())
		do ..Lookups()
		do ..Partners()
		do ..WorkflowRoles()
		$$$ThrowOnError(##class(Ens.Director).SetAutoStart(..#PRODUCTION,0))
		set ^BlastRadius.CR=141
	} catch ex { set sc=ex.AsStatus() }
	quit sc
}

/// Called by start.sh every time the container starts.
ClassMethod OnContainerStart() As %Status
{
	set sc=$$$OK
	try {
		// Stored message timestamps need to be recent, so seeding waits for the day the judge runs it.
		do ##class(Ens.Director).GetProductionStatus(.name,.state)
		if state'=1 {
			$$$ThrowOnError(##class(Ens.Director).StartProduction(..#PRODUCTION))
		}
		if $get(^BlastRadius.Seed("done"))="" {
			write "Seeding 30 days of synthetic traffic, about ten seconds...",!
			$$$ThrowOnError(##class(DemoHospital.Seed).Run())
		}
		write "Blast Radius Review is ready: http://localhost:52773/blastradius/ui/index.html",!
	} catch ex {
		set sc=ex.AsStatus()
		write "Startup failed: ",$system.Status.GetErrorText(sc),!
	}
	quit sc
}

ClassMethod WebApps() As %Status
{
	set ns=$namespace
	set sc=$$$OK
	try {
		zn "%SYS"
		for app="/blastradius/api|BlastRadius.Api.REST","/blastradius/replay|BlastRadius.Replay.Provider" {
			set name=$piece(app,"|",1)
			if ##class(Security.Applications).Exists(name) continue
			kill p
			set p("NameSpace")=ns, p("DispatchClass")=$piece(app,"|",2), p("Enabled")=1
			set p("AutheEnabled")=64, p("MatchRoles")=":%All", p("Type")=2, p("CSPZENEnabled")=1
			$$$ThrowOnError(##class(Security.Applications).Create(name,.p))
		}
		set name="/blastradius/ui"
		if '##class(Security.Applications).Exists(name) {
			kill p
			set p("NameSpace")=ns, p("Enabled")=1, p("AutheEnabled")=64, p("MatchRoles")=":%All", p("Type")=2
			set p("Path")="/home/irisowner/dev/ui", p("ServeFiles")=1, p("CSPZENEnabled")=1
			$$$ThrowOnError(##class(Security.Applications).Create(name,.p))
		}
	} catch ex { set sc=ex.AsStatus() }
	zn ns
	quit sc
}

ClassMethod Lookups()
{
	do ##class(Ens.Util.LookupTable).%UpdateValue("LabCodesToLoinc","GLU","2345-7")
	do ##class(Ens.Util.LookupTable).%UpdateValue("LabCodesToLoinc","CBC","58410-2")
	do ##class(Ens.Util.LookupTable).%UpdateValue("LabCodesToLoinc","K","2823-3")
	do ##class(Ens.Util.LookupTable).%UpdateValue("LabCodesToLoinc","TSH","3016-3")
	do ##class(Ens.Util.LookupTable).%UpdateValue("Annex7Routing","standing-orders","LAB-OLD.Router")
	do ##class(Ens.Util.LookupTable).%UpdateValue("BlastRadiusOwners","Annex 7 Clinic","Owner-Annex7")
	do ##class(Ens.Util.LookupTable).%UpdateValue("BlastRadiusOwners","Laboratory","Owner-Lab")
}

/// Business Partner records are where a production already keeps its owners. Names here are invented.
ClassMethod Partners()
{
	for row="Annex 7 Clinic|Dana Reyes|Clinic systems lead","Laboratory|Sam Okafor|Lab interface owner","Finance|Priya Nair|Billing systems owner" {
		set name=$piece(row,"|",1)
		if ##class(Ens.Config.BusinessPartner).%ExistsId(name) continue
		set bp=##class(Ens.Config.BusinessPartner).%New()
		set bp.PartnerName=name
		set bp.PrimaryContact.Name=$piece(row,"|",2)
		set bp.PrimaryContact.Title=$piece(row,"|",3)
		do bp.%Save()
	}
}

/// _SYSTEM belongs to every role, so a judge signing in with the default login sees every task in the inbox.
ClassMethod WorkflowRoles()
{
	do ##class(EnsLib.Workflow.UserDefinition).CreateUser("_SYSTEM","Demo reviewer")
	for role="Owner-Annex7","Owner-Lab","Owner-IntegrationLead" {
		do ##class(EnsLib.Workflow.RoleDefinition).CreateRole(role)
		do ##class(EnsLib.Workflow.RoleDefinition).AddUserToRole(role,"_SYSTEM")
	}
}

}
