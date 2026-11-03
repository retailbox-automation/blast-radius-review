/// Works out when a sender with a regular rhythm will send next, in Embedded Python.
/// Called only from the REST API, never from an agent tool: on build 109 a tool that reaches Embedded Python
/// can take the process down when a model asks for several tool calls in one response. See the README.
Class BlastRadius.Evidence.Rhythm Extends %RegisteredObject
{

/// pDaysAgo is a comma-separated list of how many days ago the sender was active.
/// Returns JSON {"regular":bool,"every_days":n,"next_in_days":n}. A sender is regular when the gaps between its active days are all equal.
ClassMethod NextExpected(pDaysAgo As %String) As %String [ Language = python ]
{
	import json
	days = sorted({int(d) for d in pDaysAgo.split(",") if d.strip() != ""}, reverse=True)
	if len(days) < 3:
		return json.dumps({"regular": False})
	gaps = {days[i] - days[i + 1] for i in range(len(days) - 1)}
	if len(gaps) != 1:
		return json.dumps({"regular": False})
	every = gaps.pop()
	if every < 2:
		return json.dumps({"regular": False})
	return json.dumps({"regular": True, "every_days": every, "next_in_days": every - days[-1]})
}

}
