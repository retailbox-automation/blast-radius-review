/// The workflow: agent review, code gate, owner tasks in the Workflow inbox, then a second review with the owners' answers.
Class BlastRadius.Process.Review Extends Ens.BusinessProcessBPL [ ClassType = persistent, ProcedureBlock ]
{

XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language='objectscript' request='BlastRadius.Msg.ChangeRequest' response='Ens.Response' height='1500' width='1000' >
<context>
<property name='First' type='BlastRadius.Msg.ReviewResult' instantiate='0' />
<property name='OwnerKey' type='%Integer' initialexpression='0' instantiate='0' />
<property name='CallNames' type='%String' initialexpression='""' instantiate='0' >
<parameters>
<parameter name='MAXLEN' value='' />
</parameters>
</property>
<property name='Line' type='%String' instantiate='0' >
<parameters>
<parameter name='MAXLEN' value='' />
</parameters>
</property>
<property name='Answers' type='%String' initialexpression='"[]"' instantiate='0' >
<parameters>
<parameter name='MAXLEN' value='' />
</parameters>
</property>
</context>
<sequence xend='200' yend='1100' >
<call name='Agent review' target='BlastRadius.Agent' async='0' xpos='200' ypos='250' >
<annotation>The AI Hub agent gathers evidence and proposes. The code gate sets the floor.</annotation>
<request type='BlastRadius.Msg.ReviewRequest' >
<assign property="callrequest.CRId" value="request.CRId" action="set" />
<assign property="callrequest.Text" value="request.Text" action="set" />
<assign property="callrequest.Round" value="1" action="set" />
</request>
<response type='BlastRadius.Msg.ReviewResult' >
<assign property="context.First" value="callresponse" action="set" />
</response>
</call>
<if name='Anyone to ask?' condition='context.First.Owners.Count()&gt;0' xpos='200' ypos='350' xend='200' yend='1000' >
<true>
<foreach name='Each owner' property='context.First.Owners' key='context.OwnerKey' xpos='335' ypos='500' xend='200' yend='450' >
<assign name='Next task' property="context.Line" value="context.First.Owners.GetAt(context.OwnerKey)" action="set" xpos='200' ypos='250' />
<assign name='Remember the call' property="context.CallNames" value='context.CallNames_$select(context.CallNames="":"",1:",")_"Ask owner "_context.OwnerKey' action="set" xpos='200' ypos='300' />
<call name='@"Ask owner "_context.OwnerKey' target='@$piece(context.Line,"|",1)' async='1' xpos='200' ypos='350' >
<annotation>A task in the Workflow inbox of the item's Business Partner.</annotation>
<request type='EnsLib.Workflow.TaskRequest' >
<assign property="callrequest.%Subject" value='$piece(context.Line,"|",3)' action="set" />
<assign property="callrequest.%Message" value='$piece(context.Line,"|",4)' action="set" />
<assign property="callrequest.%Actions" value='"Confirm,Reject"' action="set" />
<assign property="callrequest.%FormFields" value='"Comment"' action="set" />
</request>
<response type='EnsLib.Workflow.TaskResponse' >
<assign property="context.Answers" value='##class(BlastRadius.Process.Answers).Add(context.Answers,callresponse)' action="set" />
</response>
</call>
</foreach>
<sync name='Wait for owners' calls='@context.CallNames' type='all' xpos='335' ypos='550' />
<call name='Review with answers' target='BlastRadius.Agent' async='0' xpos='335' ypos='600' >
<annotation>Same agent, same evidence tools, now with what the owners said.</annotation>
<request type='BlastRadius.Msg.ReviewRequest' >
<assign property="callrequest.CRId" value="request.CRId" action="set" />
<assign property="callrequest.Text" value="request.Text" action="set" />
<assign property="callrequest.Round" value="2" action="set" />
<assign property="callrequest.OwnerAnswers" value="context.Answers" action="set" />
</request>
<response type='BlastRadius.Msg.ReviewResult' />
</call>
</true>
</if>
</sequence>
</process>
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
