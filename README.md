# Blast Radius Review

Before anyone changes a live IRIS integration, an AI Hub agent checks who still sends to what the change touches, tests the change on stored messages, and says whether to go ahead. It never applies anything itself.

Built for the InterSystems programming contest *AI Agents in Interoperability Workflows*. Runs on **AI Hub Community build 2027.1.0AI.109.0, IRIS for Health**.

![The decision screen: HOLD, with annex-7 in red close to LAB-OLD.Router, and ORC-12 lost in 3 of 120 stored messages](docs/images/decision-hold.png)

An engineer writes "Retire LAB-OLD; everything moved to LAB-NEW last month." Everything had moved, except `annex-7`:

```
HOLD
annex-7 sends to LAB-OLD.Router (41 messages in 30 days, Tuesdays 06:00 UTC), and nothing declares that link.
Shadow-run: 3 of 120 stored messages lose field ORC-12, and nothing says that is intended.
```

Its target is read from a Lookup Table at run time, so neither the production diagram nor Interface Maps can show it. The message headers can.

Most AI work on productions looks at messages after something has gone wrong. This looks at a change to the production before anyone makes it.

## Judge it in two minutes

You need the AI Hub image loaded and retagged first ([Quick start](#quick-start), steps 1 and 2). Then:

```bash
git clone https://github.com/retailbox-automation/blast-radius-review.git && cd blast-radius-review
docker compose up -d                                   # builds and starts, about a minute the first time
curl -s http://localhost:52773/blastradius/api/health  # repeat until it says "ready":true
```

Open http://localhost:52773/blastradius/ui/index.html. No key and no model are needed.

1. **Retire the old lab** gives HOLD and names `annex-7`, a sender no configuration declares.
2. Press **Confirm** on both owner tasks. The agent reviews again and says APPLY-AFTER-DRAIN, because 4 messages are still queued.
3. **Just apply it** shows `DENIED ApplyChange` in the audit list: the agent cannot apply anything.
4. `tests/run.sh` runs every test class inside the container.

## Why this exists

Every integration team asks the same question before retiring or changing an interface: who still uses this? The honest answer is usually in somebody's head. A real hospital group described in the literature runs [534 interfaces on seven production servers, 86 of them legacy](https://www.scitepress.org/Papers/2021/102420/102420.pdf) (Linecker and Wöß, HEALTHINF 2021). Nobody holds that list in their head.

I know what the wrong answer costs. On a migration night in 2026 a shared address was moved because the list said about 20 of our domains sat behind it. Hundreds of other stores did too, and they were down for about four hours. The list had been made from our own records, and it was wrong because nobody looked at the traffic. This project is that check, as an Interoperability workflow, for the people who run IRIS productions.

## How this answers the contest task

A change request is an Interoperability message. It enters through a Business Service and runs through a BPL process:

```
REST or portal
   │
   ▼
BlastRadius.ChangeRequests   Business Service
   │
   ▼
BlastRadius.Review           BPL process
   ├── BlastRadius.Agent     Business Operation on the stock EnsLib.AI.Agent.OutboundAdapter.
   │     │                   The AI Hub agent reads the production and proposes a verdict.
   │     ├── tools           configuration, 30 days of traffic, queue depth, shadow-run, owners
   │     └── code gate       works out the softest verdict the evidence allows
   ├── Owner-Annex7, Owner-Lab   Workflow tasks, on a HOLD, to the owners on record
   └── BlastRadius.Agent     second review, now with what the owners answered
```

The decision has four outcomes: **APPLY**, **APPLY-AFTER-DRAIN**, **CANARY-FIRST**, **HOLD**. The whole review is one session, so you can follow it in Visual Trace like any other message flow, tool calls included.

![Visual Trace of one review: the change request, the review request, then one message per agent tool call](docs/images/visual-trace.png)

## Check it yourself

| Claim | How to check | What you will see |
|---|---|---|
| The agent finds a sender no configuration declares | Run the first preset | HOLD naming `annex-7`, 41 messages, Tuesdays 06:00 UTC |
| The portal cannot show that sender | Open *Interoperability > View > Interface Maps* | Five feeds, `orders-research` and the ADT route, but no row for `annex-7`: its target comes from a Lookup Table at run time |
| The shadow-run is real | `tests/run.sh EvidenceTest` | `TestShadowRunFindsTheLostField`, against stored HL7 and the real DTL classes |
| A shadow-run touches nothing | same | `TestShadowRunSavesNothing` counts rows before and after |
| The agent cannot apply a change | Run the *"Just apply it"* preset, then look at the card's audit list | `DENIED ApplyChange`, from the Authorization policy |
| Code outranks the model | `tests/run.sh GateTest` | `TestUnnamedSenderOverridesAgentApply`: the model says APPLY, the gate says HOLD |
| Owners really change the outcome | `tests/run.sh EndToEndTest` | Two owners confirm: APPLY-AFTER-DRAIN. One rejects: HOLD |
| No key is needed to try all of this | Follow the quick start | Every tool, policy and gate runs for real. Only the model's words are recorded |
| Each model call is traced like any message | Open Visual Trace from the card, click the `ReviewResult` message | Model, prompt and completion tokens, tool calls, time and the prompt version; `TestTraceShowsTheModelCallAndItsPromptVersion` checks the version against what the model received |

### Where to look, by judging criterion

| Criterion | Where to look |
|---|---|
| Complexity | [Agent proposes, code decides](#agent-proposes-code-decides): traffic, shadow-run of real DTL classes on stored HL7, a code floor under the verdict, a second round with the owners' answers |
| Clarity of Instructions | [Judge it in two minutes](#judge-it-in-two-minutes), [Quick start](#quick-start), [Troubleshooting](#troubleshooting) |
| Developer Experience | Replay needs no key, `tests/run.sh` runs the suite, [IPM](#install-with-ipm), [a real model](#run-it-with-a-real-model) is a few lines of `.env` |
| Applicability | [Point it at your own production](#point-it-at-your-own-production): the tools read whatever production runs in the namespace |
| Usability | The decision screen, the Workflow inbox and Visual Trace, all from the card |

### Contest bonuses

Points are the organizers' list; they decide what counts.

| Bonus | Points | Here |
|---|---|---|
| Workflow Engine | 2 | Owner tasks are `EnsLib.Workflow` tasks, and their answers go back into the BPL ([step 5](#quick-start)) |
| Docker | 2 | `docker compose up -d` |
| Embedded Python | 3 | `BlastRadius.Evidence.Rhythm` predicts a sender's next run, called from the REST API ([why not from a tool](#platform-findings)) |
| ZPM package | 2 | `module.xml`, [Install with IPM](#install-with-ipm) |
| Community idea | 4 | [DPI-I-689](#tracing-the-agent-like-any-other-message-flow) |
| Bugs in AI Hub | 2 + 1 | [#15](https://github.com/intersystems-community/ai-hub-eap-bugreports/issues/15) and [#16](https://github.com/intersystems-community/ai-hub-eap-bugreports/issues/16) |
| Questionnaire | 1 | Filled in |

## Quick start

You need Docker with Compose 2.24 or newer and about 15 GB free. It takes about five minutes the first time.

**1. Get the image.** It is not on any public registry, so download it yourself from the [Early Access portal](https://evaluation.intersystems.com/Eval/early-access/AIHub) (*AI Hub* program): `irishealth-community-2027.1.0AI.109.0-docker.tar.gz` for x64, or `irishealth_arm64-community-2027.1.0AI.109.0-docker.tar.gz` for Apple Silicon and other ARM machines. The plain `iris-community` image will not work: it has no HL7 classes.

**2. Load and retag it.**

```bash
docker image load -i irishealth_arm64-community-2027.1.0AI.109.0-docker.tar.gz
docker tag docker.iscinternal.com/docker-intersystems/intersystems/irishealth-community:2027.1.0AI.109.0 \
           irishealth-community:2027.1.0AI.109.0
```

`docker image load` prints the name it loaded. If yours differs, use that name in the tag command. I tested on ARM only; the x64 file name above comes from the portal.

**3. Start it.**

```bash
git clone https://github.com/retailbox-automation/blast-radius-review.git
cd blast-radius-review
docker compose up -d
```

The first build compiles everything in about a minute. On first start the container sends 1,400 synthetic HL7 messages through the production and moves their timestamps back across 30 days, which takes about ten seconds. Wait until this says `"ready":true`:

```bash
curl -s http://localhost:52773/blastradius/api/health
```

**4. Open the decision screen:** http://localhost:52773/blastradius/ui/index.html

Pick **Retire the old lab**. You should see HOLD within a second or two. Portal login, wherever it asks: `_SYSTEM` / `SYS`.

**5. Answer the owners.** The screen shows two tasks. Press **Confirm** on both, here or in the [Workflow inbox](http://localhost:52773/csp/healthshare/blastradius/_DeepSee.UserPortal.Workflow.zen). The process carries on by itself and the second review ends at **APPLY-AFTER-DRAIN**, because 4 messages are still queued on `LAB-OLD.Out`. Press **Reject** on one instead and it stays at HOLD.

![The same review after both owners confirmed: APPLY-AFTER-DRAIN, 4 queued](docs/images/decision-after-drain.png)

**6. Look at it from the IRIS side.** Scroll down the decision screen: the gate's reasons, every sender, every field difference, each tool call, and links to Visual Trace for the session, Message Viewer and the production. The tasks are ordinary Workflow tasks, and the review items sit in the production next to the hospital's, under the `BlastRadius` category.

![Workflow inbox with the two owner tasks](docs/images/workflow-inbox.png)

**7. Run the tests.**

```bash
tests/run.sh
```

## The demo production

A synthetic hospital. All names and identifiers are invented, and there is no patient data.

| Item | What it is |
|---|---|
| `orders-ed`, `orders-inpatient`, `orders-surgery`, `orders-oncology`, `orders-outpatient` | Order feeds. They moved to `LAB-NEW.Router` four weeks ago, and their settings say so |
| `orders-research` | Disabled for months. Its setting still names `LAB-OLD.Router`, so configuration is wrong in this direction too |
| `annex-7` | A clinic's weekly batch. Its target is read from a Lookup Table at run time, so nothing declares the link |
| `LAB-OLD.Router`, `LAB-OLD.Out` | The legacy lab route. Its analyser link is down, so 4 messages wait in the queue |
| `LAB-NEW.Router`, `LAB-NEW.Out` | The new lab route |
| `adt-feed`, `ADT.Router`, `bed-board.Out`, `billing.Out`, `nightly-report.Out` | Neighbours, so the agent has to find the right items in a real list |

`OrderToLabNew` was written for the five feeds that send one order per message, and it only keeps the ordering provider on the first order. Nobody noticed. `annex-7` sends multi-order messages, so moving it would have lost `ORC-12` on three of them. The agent connects the two findings because the shadow-run reports which senders each difference came from. `OrderToLabNewV2` is the candidate that keeps the field.

## What is new here

The portal already knows a lot. *Interface Maps* and the production diagram read settings, routing rules, and literal targets in code (`Ens.Config.Production.GetConnections` scans for `SendRequestAsync("...")`). If that answers your question, you do not need this.

This adds what they cannot know:

- **Traffic.** `Ens.MessageHeader` shows who sent what, last week. A target computed at run time from a lookup, a variable or `@context.x` in BPL appears nowhere else.
- **A trial on real history.** The current and candidate transforms run over stored message bodies, and the two outputs are compared field by field. Nothing is saved or sent.
- **A decision with reasons, and people.** The agent reads a sentence, works out which items it means, and judges whether each difference was meant to happen. Owners get a task and their answer feeds the next review.

## Agent proposes, code decides

The model is good at two things here: mapping words to production items, and judging whether a difference in a field was intended given what the request says. It is not trusted with the rest.

`BlastRadius.Gate.Floor` reads what the tools returned, not the agent's account of them, and works out the softest verdict the evidence allows. The agent can be stricter than that floor, never softer, within what the gate looks at:

- traffic: the items the decision names, the items the request names (the whole name, or the part before the dot, so "LAB-OLD" covers `LAB-OLD.Router` and `LAB-OLD.Out`), and the routers configured in front of all of them. If the agent named only `LAB-OLD.Out`, the gate still reads the traffic of `LAB-OLD.Router` and finds `annex-7`;
- queues: the items the decision or the request names;
- shadow-runs: every router the decision names, each one separately.

| Rule | Floor |
|---|---|
| No decision, an unknown verdict, or no item the production has | HOLD |
| An owner answered anything but Confirm, in either round, whether or not this round's evidence still shows their point | HOLD |
| A traffic check that failed. If the agent skipped a check or looked at fewer than 30 days, the gate runs it itself and judges the result | HOLD |
| An active sender nothing declares, unless its owner confirmed or a sentence of the request commits to something for it ("the owner of annex-7 will re-point it", "retire annex-7 too"). A mention such as "I have no idea who annex-7 is" does not count | HOLD |
| A shadow-run difference not marked intended, and not accepted by an owner. Every run in both rounds counts, not only the last | HOLD |
| A named router that transforms live traffic, without a shadow-run of its own: one that processed messages, starts from the transform the router uses now, and tries a transform another router uses or the request names. A run that tried a router's own transform on the traffic moving to it covers that router too | HOLD |
| Messages still queued on what is changing | APPLY-AFTER-DRAIN |

Active means the sender sent in the last 14 days, or sent earlier in the window and has sent nowhere else since, which is how a monthly batch looks. The feeds that moved have sent elsewhere, so they do not count. Whether a difference is intended stays the agent's judgement, which is the one thing here it is trusted with.

The model is also propose-only by policy. `BlastRadius.Agent.Auth` is an allow list on `%AI.Policy.Authorization`, and `ApplyChange` is not on it. The tool exists so the refusal can be seen: `BlastRadius.Agent.Audit` writes it to a table through `%LogDenial`.

## Run it with a real model

Replay is the default so you can try everything without a key. To review your own requests, copy `.env.example` to `.env`, set these, and run `docker compose up -d`:

```bash
BR_LLM_MODE=live
BR_LLM_PROVIDER=openai        # openai, anthropic, gemini, bedrock...
BR_LLM_MODEL=gpt-5-nano
BR_LLM_API_KEY=your-key-here
BR_LLM_BASE_URL=              # any OpenAI-compatible endpoint, or empty
```

A free local model works too, through Ollama on the host. One review sends about 20,000 tokens of context, and Ollama may give a model a smaller window by default, so make a variant with a 32K window first:

```bash
printf 'FROM gemma4:31b\nPARAMETER num_ctx 32768\n' > Modelfile.32k
ollama create gemma4:31b-32k -f Modelfile.32k
```

```bash
BR_LLM_MODE=live
BR_LLM_MODEL=gemma4:31b-32k
BR_LLM_API_KEY=none
BR_LLM_BASE_URL=http://host.docker.internal:11434/v1
```

The recordings in `replay/` were made this way, with `gemma4:31b` running locally (the earliest ones before the 32K variant). Set `BR_PRICE_IN` and `BR_PRICE_OUT` (dollars per million tokens) and the card prices each decision. A live review may run for up to 15 minutes; `BR_LLM_TIMEOUT_S` changes that.

How replay works: `BlastRadius.Replay.Provider` is a small REST class that speaks the OpenAI chat-completions protocol and answers from recordings. To AI Hub it is just another provider, so the agent loop, policies, audit, tool calls, SQL and DTL all run for real. A request with no recording gets an honest HOLD that says so. In replay mode only the presets have recordings.

## Point it at your own production

The evidence tools read whichever production is running in the namespace, so nothing in them knows about the demo. To try it on your own:

1. Load `src/BlastRadius` into your namespace.
2. Add the `BlastRadius.*` items and at least one `EnsLib.Workflow.Operation` to your production, with the category `BlastRadius` so they are left out of the review.
3. Fill the `BlastRadiusOwners` lookup: Business Partner name to Workflow role.

## Install with IPM

The package needs IRIS for Health with AI Hub and a namespace with Interoperability enabled. I tested it on build 2027.1.0AI.109.0. The AI Hub image has no package manager, so install it first:

```objectscript
zn "%SYS"
set r=##class(%Net.HttpRequest).%New(),r.Server="pm.community.intersystems.com",r.Https=1,r.SSLConfiguration="ISC.FeatureTracker.SSL.Config"
do r.Get("/packages/zpm/latest/installer"),$system.OBJ.LoadStream(r.HttpResponse.Data,"c")
zpm "enable -map -globally"
```

Then, in your namespace:

```objectscript
zpm "install blast-radius-review"
```

A clone works too: `zpm "load /path/to/blast-radius-review"`. The package starts the demo production and seeds it in the background, and the screen is ready about ten seconds after the command returns, at `/blastradius/ui/index.html`. `tools/ipm_test.sh` does all of this in a throwaway container.

Use a test instance. This is a demo, so its web applications ask for no password, and replay expects the web server on port 52773.

## Models and cost

These are the recordings in `replay/` made on 7 November 2026, with `gemma4:31b-32k` running locally through Ollama on a Mac Studio. Cost was $0.

| Request | Round | Prompt + completion tokens | Tool calls | Verdict |
|---|---|---|---|---|
| Retire the old lab | 1 | 17,218 + 3,065 | 12 | HOLD |
| same, both owners confirm | 2 | 17,688 + 2,222 | 11 | APPLY-AFTER-DRAIN |
| same, annex-7's owner rejects | 2 | 17,665 + 2,263 | 11 | HOLD |
| same, the lab's owner rejects | 2 | 17,654 + 2,095 | 11 | HOLD |
| same, both reject | 2 | 19,848 + 2,812 | 11 | HOLD |
| "Just apply it" | 1 | 21,218 + 7,371 | 11 | HOLD, `ApplyChange` denied |
| same, annex-7's owner confirms | 2 | 22,255 + 5,916 | 14 | HOLD, `ApplyChange` denied again |

Both rounds of one review took 2.3 to 2.8 minutes for the retire request and 6.5 minutes for "Just apply it". In all five reviews the final verdict after round two was the agent's own, so the gate did not have to raise it. In "Just apply it" the agent was stricter than the floor: the floor was APPLY-AFTER-DRAIN, the agent kept HOLD.

On an earlier run, a review with 13 tool calls took 5.6 minutes on the same machine and hit the 300-second limit I had set, which is why the limit is now a setting.

The screen shows tokens and tool calls for each review, and the cost when it knows the price. It never guesses a price: set `BR_PRICE_IN` and `BR_PRICE_OUT` for a hosted model. Every tool call is one row in `BlastRadius_Data.AuditEvent` and one message in Visual Trace, so you can see what the agent did, in what order, and what it was refused.

## Tracing the agent like any other message flow

This implements the Community idea [DPI-I-689, "Use InterSystems Interoperability as a Traceability tool for GenAI LLM pipelines"](https://ideas.intersystems.com/ideas/DPI-I-689). The production itself is the trace store, so no separate tracing service is needed.

Open any review in Visual Trace (the card links to its session) and you will find:

| Message | Where it goes | What it carries |
|---|---|---|
| `BlastRadius.Msg.ReviewRequest` | `BlastRadius.Agent` | The change request, the round, and the owners' answers in round two |
| `BlastRadius.Msg.ToolCallRecord`, one per tool call | `BlastRadius.ToolLedger` | Tool name, arguments, outcome (`ALLOWED`, `FAILED` or `DENIED`), result and time |
| `BlastRadius.Msg.ReviewResult` | back to the process | Model, mode (live or replay), prompt tokens, completion tokens, number of tool calls, time, and `PromptVersion` |

`PromptVersion` is the first 12 hex digits of SHA-256 over the agent's instructions (`XData INSTRUCTIONS` in `BlastRadius.Agent.Reviewer`). If you change one word of the instructions, the next review shows a new version, so you can tell which wording produced a decision. In replay mode it names the instructions sent on this run, and the recorded answers may come from an earlier wording. New recordings store the version they were made with as `prompt_version`.

The same records answer the questions a tracing service would, in SQL (*System Explorer > SQL*, namespace `BLASTRADIUS`):

```sql
-- tokens, tool calls, time and prompt version of each review round
SELECT CRId, Round, Model, Mode, PromptTokens, CompletionTokens, ToolCalls, DurationMs, PromptVersion
FROM BlastRadius_Msg.ReviewResult ORDER BY ID DESC

-- every tool call of one review, in order
SELECT Round, Tool, Outcome, DurationMs FROM BlastRadius_Msg.ToolCallRecord WHERE CRId = ? ORDER BY ID

-- everything the agent was refused
SELECT CRId, Tool, Outcome FROM BlastRadius_Data.AuditEvent WHERE Outcome = 'DENIED'
```

Because these are ordinary messages, the usual tools apply: Message Viewer search, purge settings, and SQL on `Ens.MessageHeader` and the message tables. They also sit in the same session as the HL7 traffic the review is about. A dedicated LLM tracing service such as Langfuse records each model call separately. Here tokens and time are totals for each round, and the tool calls are the steps.

## Platform findings

Things I ran into on build 109, in case they save you time:

- **The plain `iris-community` image has no HL7.** `SELECT Name FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH 'EnsLib.HL7'` returns nothing. HL7 work needs `irishealth-community`.
- **Embedded Python in a tool can crash the process.** When a model asks for several tool calls in one response and a tool reaches a `[ Language = python ]` method, the job can die with signal 11, with no error to catch, and its message stays queued. I reproduced it without my code or a key and reported it as [bug 15](https://github.com/intersystems-community/ai-hub-eap-bugreports/issues/15). This is why the field diff here is ObjectScript, and why the one Python method in this project (`BlastRadius.Evidence.Rhythm`, which predicts a sender's next run) is called from the REST API and not from a tool.
- **An empty model turn breaks the next request in the session.** When a model stops with no text and no tool call, AI Hub keeps that turn and sends it back on the next `Chat()` as `{"role":"assistant"}`, with no `content`. Ollama rejects the whole request with HTTP 400 `invalid message content type: <nil>`. On `gemma4:31b` this broke 4 of 6 reviews in one recording session, because a review that ends without a decision gets one reminder in the same session. The reminder now drops the empty turn first. `tools/empty_turn_check.sh` shows the failure and the fix against a stand-in server, with no model, and the minimal case is [bug 16](https://github.com/intersystems-community/ai-hub-eap-bugreports/issues/16).
- **`EnsLib.AI.Agent.OutboundAdapter` works and has no documentation.** Its source in the image is the reference. `AgentClass`, `AuthPolicy` and `AuditPolicy` are production settings, and `OnBeforeAgentInit` is a good place to choose a provider from the environment.
- **Every class method of a `%AI.Tool` class is offered to the model.** A helper of mine showed up as a tool and a model called it. Only the allow list stopped it. Helpers belong in another class, and `tests` checks that with `%Discover()`.
- **`%SQL.Statement.%ExecDirect` does not throw on a bad statement.** `%Next()` returns 0, which an agent tool reads as "no rows", or here, "nobody uses this". All SQL here goes through `BlastRadius.Evidence.Sql`, which throws.
- **Two time limits are worth knowing.** `timeout_ms` in the session config limits a whole run, with `<%AICore>Timeout: Wall-clock timeout (300000 ms) exceeded before a final response`. `request_timeout_secs` under `http_config` in the provider config limits one model request. I found both names by reading strings in `irisllm.so`. `BlastRadius.Agent.Adapter` sets both from `BR_LLM_TIMEOUT_S`.
- **AI Hub stops a model that keeps getting the same tool result:** `<%AICore>LoopDetected: Agentic loop stalled: no new evidence from tool results after 4 assessment(s)`. I saw this with a fake provider that repeated one call.
- **A production cannot start from an IPM `Invoke`.** `Ens.Director.StartProduction` failed with `ErrCanNotAcquireRuntimeLock` after 30 seconds, and what the method had already set was rolled back, so the package manager runs it inside a transaction. `BlastRadius.Install.AtIpmInstall` leaves the start to a background job that waits for the transaction to end.
- **`call.arguments` is a JSON string in audit hooks and an object in authorization hooks** (known, bug report 14, still so on 109).

## Limitations

This is a prototype, built in a contest window.

- It reviews one namespace's running production.
- The shadow-run compares HL7 messages only. It samples 120: every sender gets a share, and the rest go to the newest messages.
- CANARY-FIRST is a verdict. There is no canary mechanism behind it.
- Traffic can only show what was sent inside the window. A sender that runs once a quarter stays invisible unless the window covers it.
- A shadow-run executes your transforms on stored messages. Custom code in a transform that has side effects will still have them.
- Demo web applications have no authentication, and ports bind to `127.0.0.1`. Do not expose them.
- The gate only asks for a shadow-run on routers the decision names. A router that neither the decision nor the request names, and that is not configured in front of something they name, is outside what the gate checks.
- A sender that is declared in the configuration and still active does not raise the floor on its own: the gate flags undeclared senders. Retiring an item that a declared feed still uses relies on the agent's review.
- A quiet sender that also sends somewhere else in the same batch counts as moved. The demo has no such sender.

## Troubleshooting

| You see | Do this |
|---|---|
| `pull access denied` for `irishealth-community` | Step 2 did not run. Load and retag the image |
| `"ready":false` for more than two minutes | `docker logs blast-radius-review` shows the seed or the error |
| HOLD saying replay only knows the recorded requests | That text has no recording. Pick a preset, or switch to live mode |
| Port 52773 or 1972 already in use | Stop the other IRIS container |
| Counts differ from this README some days after the first start | `docker compose restart`. A seed older than a day is replaced on start, and the earlier reviews go with it |
| You pulled new commits into an existing clone and the screen behaves as before | `docker compose up -d --build`. The code is compiled into the image and the demo is seeded from it, so a plain restart keeps the old build |

## Build history and AI assistance

Code was written with AI coding assistants under my direction. The contest allows this. The design, the production, the demo story and every claim in this README were checked against the running system.
