/// A synthetic hospital integration production, plus the Blast Radius Review items that watch it.
/// Everything in the "BlastRadius" category is the review tool; everything else is the production under review.
Class DemoHospital.Production Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="DemoHospital.Production" TestingEnabled="true" LogGeneralTraceEvents="false">
  <Description>Synthetic hospital feeds under review by Blast Radius Review. No real patient data.</Description>
  <ActorPoolSize>2</ActorPoolSize>

  <!-- Five order feeds. They were moved to LAB-NEW about four weeks ago, and their settings say so. -->
  <Item Name="orders-ed" Category="Orders" ClassName="DemoHospital.Feed.OrdersService" PoolSize="0" Enabled="true" Comment="Emergency department orders">
    <Setting Target="Host" Name="TargetConfigNames">LAB-NEW.Router</Setting>
    <Setting Target="Host" Name="MessageSchemaCategory">2.5</Setting>
    <Setting Target="Host" Name="BusinessPartner">Emergency Department</Setting>
  </Item>
  <Item Name="orders-inpatient" Category="Orders" ClassName="DemoHospital.Feed.OrdersService" PoolSize="0" Enabled="true" Comment="Ward orders">
    <Setting Target="Host" Name="TargetConfigNames">LAB-NEW.Router</Setting>
    <Setting Target="Host" Name="MessageSchemaCategory">2.5</Setting>
    <Setting Target="Host" Name="BusinessPartner">Inpatient Services</Setting>
  </Item>
  <Item Name="orders-surgery" Category="Orders" ClassName="DemoHospital.Feed.OrdersService" PoolSize="0" Enabled="true" Comment="Pre-op orders">
    <Setting Target="Host" Name="TargetConfigNames">LAB-NEW.Router</Setting>
    <Setting Target="Host" Name="MessageSchemaCategory">2.5</Setting>
    <Setting Target="Host" Name="BusinessPartner">Surgery</Setting>
  </Item>
  <Item Name="orders-oncology" Category="Orders" ClassName="DemoHospital.Feed.OrdersService" PoolSize="0" Enabled="true" Comment="Oncology clinic orders">
    <Setting Target="Host" Name="TargetConfigNames">LAB-NEW.Router</Setting>
    <Setting Target="Host" Name="MessageSchemaCategory">2.5</Setting>
    <Setting Target="Host" Name="BusinessPartner">Oncology</Setting>
  </Item>
  <Item Name="orders-outpatient" Category="Orders" ClassName="DemoHospital.Feed.OrdersService" PoolSize="0" Enabled="true" Comment="Outpatient clinic orders">
    <Setting Target="Host" Name="TargetConfigNames">LAB-NEW.Router</Setting>
    <Setting Target="Host" Name="MessageSchemaCategory">2.5</Setting>
    <Setting Target="Host" Name="BusinessPartner">Outpatient Clinics</Setting>
  </Item>

  <!-- Disabled since spring. Its setting still names LAB-OLD, so configuration is wrong in this direction too. -->
  <Item Name="orders-research" Category="Orders" ClassName="DemoHospital.Feed.OrdersService" PoolSize="0" Enabled="false" Comment="Research study orders, study closed">
    <Setting Target="Host" Name="TargetConfigNames">LAB-OLD.Router</Setting>
    <Setting Target="Host" Name="MessageSchemaCategory">2.5</Setting>
    <Setting Target="Host" Name="BusinessPartner">Clinical Research</Setting>
  </Item>

  <!-- The weekly batch. Its target comes from a lookup table at run time, so neither the diagram nor Interface Maps can show it. -->
  <Item Name="annex-7" Category="Orders" ClassName="DemoHospital.Feed.Annex7Batch" PoolSize="0" Enabled="true" Comment="Annex 7 standing orders">
    <Setting Target="Host" Name="BusinessPartner">Annex 7 Clinic</Setting>
  </Item>

  <Item Name="LAB-OLD.Router" Category="Lab" ClassName="EnsLib.HL7.MsgRouter.RoutingEngine" PoolSize="1" Enabled="true" Comment="Legacy lab router">
    <Setting Target="Host" Name="BusinessRuleName">DemoHospital.Rules.LabOld</Setting>
    <Setting Target="Host" Name="Validation"></Setting>
    <Setting Target="Host" Name="BusinessPartner">Laboratory</Setting>
  </Item>
  <!-- Disabled: the analyser link is down, so what is sent to it waits in its queue. The seed enables it while loading history. -->
  <Item Name="LAB-OLD.Out" Category="Lab" ClassName="DemoHospital.Lab.SinkOperation" PoolSize="1" Enabled="false" Comment="Legacy lab analyser interface, link down">
    <Setting Target="Host" Name="BusinessPartner">Laboratory</Setting>
  </Item>
  <Item Name="LAB-NEW.Router" Category="Lab" ClassName="EnsLib.HL7.MsgRouter.RoutingEngine" PoolSize="1" Enabled="true" Comment="New lab router">
    <Setting Target="Host" Name="BusinessRuleName">DemoHospital.Rules.LabNew</Setting>
    <Setting Target="Host" Name="Validation"></Setting>
    <Setting Target="Host" Name="BusinessPartner">Laboratory</Setting>
  </Item>
  <Item Name="LAB-NEW.Out" Category="Lab" ClassName="DemoHospital.Lab.SinkOperation" PoolSize="1" Enabled="true" Comment="New lab system interface">
    <Setting Target="Host" Name="BusinessPartner">Laboratory</Setting>
  </Item>

  <!-- Unrelated neighbours, so the agent has to pick the right items out of a real list. -->
  <Item Name="adt-feed" Category="ADT" ClassName="DemoHospital.Feed.OrdersService" PoolSize="0" Enabled="true" Comment="Patient administration events">
    <Setting Target="Host" Name="TargetConfigNames">ADT.Router</Setting>
    <Setting Target="Host" Name="MessageSchemaCategory">2.5</Setting>
    <Setting Target="Host" Name="BusinessPartner">Patient Administration</Setting>
  </Item>
  <Item Name="ADT.Router" Category="ADT" ClassName="EnsLib.HL7.MsgRouter.RoutingEngine" PoolSize="1" Enabled="true" Comment="ADT router">
    <Setting Target="Host" Name="BusinessRuleName">DemoHospital.Rules.Adt</Setting>
    <Setting Target="Host" Name="Validation"></Setting>
    <Setting Target="Host" Name="BusinessPartner">Patient Administration</Setting>
  </Item>
  <Item Name="bed-board.Out" Category="ADT" ClassName="DemoHospital.Lab.SinkOperation" PoolSize="1" Enabled="true" Comment="Bed management system">
    <Setting Target="Host" Name="BusinessPartner">Patient Administration</Setting>
  </Item>
  <Item Name="billing.Out" Category="ADT" ClassName="DemoHospital.Lab.SinkOperation" PoolSize="1" Enabled="true" Comment="Billing system">
    <Setting Target="Host" Name="BusinessPartner">Finance</Setting>
  </Item>
  <Item Name="nightly-report.Out" Category="Reports" ClassName="DemoHospital.Lab.SinkOperation" PoolSize="1" Enabled="true" Comment="Old nightly lab report, unused since the summer">
    <Setting Target="Host" Name="BusinessPartner">Laboratory</Setting>
  </Item>

  <!-- Blast Radius Review: the change request is a message, like everything else in this production. -->
  <Item Name="BlastRadius.ChangeRequests" Category="BlastRadius" ClassName="BlastRadius.Service.ChangeRequests" PoolSize="0" Enabled="true" Comment="REST and portal entry point for change requests">
    <Setting Target="Host" Name="TargetConfigName">BlastRadius.Review</Setting>
  </Item>
  <Item Name="BlastRadius.Review" Category="BlastRadius" ClassName="BlastRadius.Process.Review" PoolSize="1" Enabled="true" Comment="Agent review, code gate, owner tasks, re-review"/>
  <Item Name="BlastRadius.Agent" Category="BlastRadius" ClassName="BlastRadius.Operation.Agent" PoolSize="1" Enabled="true" Comment="Hosts the AI Hub agent">
    <Setting Target="Adapter" Name="AgentClass">BlastRadius.Agent.Reviewer</Setting>
    <Setting Target="Adapter" Name="AuthPolicy">BlastRadius.Agent.Auth</Setting>
    <Setting Target="Adapter" Name="AuditPolicy">BlastRadius.Agent.Audit</Setting>
    <Setting Target="Adapter" Name="SessionConfigString">{"max_iterations":14,"max_tokens":2500,"timeout_ms":300000}</Setting>
  </Item>
  <Item Name="BlastRadius.ToolLedger" Category="BlastRadius" ClassName="BlastRadius.Operation.ToolLedger" PoolSize="1" Enabled="true" Comment="Shows each agent tool call in Visual Trace"/>
  <Item Name="Owner-Annex7" Category="BlastRadius" ClassName="EnsLib.Workflow.Operation" PoolSize="1" Enabled="true" Comment="Workflow role: owner of annex-7">
    <Setting Target="Host" Name="AutoCreateRole">1</Setting>
  </Item>
  <Item Name="Owner-Lab" Category="BlastRadius" ClassName="EnsLib.Workflow.Operation" PoolSize="1" Enabled="true" Comment="Workflow role: laboratory interface owner">
    <Setting Target="Host" Name="AutoCreateRole">1</Setting>
  </Item>
  <Item Name="Owner-IntegrationLead" Category="BlastRadius" ClassName="EnsLib.Workflow.Operation" PoolSize="1" Enabled="true" Comment="Workflow role: fallback when an item has no named owner">
    <Setting Target="Host" Name="AutoCreateRole">1</Setting>
  </Item>
</Production>
}

}
