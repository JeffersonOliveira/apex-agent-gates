# apex-agent-gates

Laboratório público da palestra "Agente de código no Apex sem perder o controle" (Brazil Dreamin' 2026, 12 de novembro, São Paulo). É um projeto Salesforce DX que reproduz os três casos da palestra e os três portões (regras do projeto, hooks e pipeline), usando só Case e Opportunity padrão e dois campos customizados.

> **Aviso:** as classes `CaseNoteSummaryService.cls` e `OpportunityLineTotals.cls` são inseguras de propósito. Elas espelham o erro que o agente cometeu: vazamento de campo por falta de user mode e estouro de limite por SOQL em laço. Não copie essas classes para um projeto real. As versões revisadas são `CaseNoteSummaryServiceSafe.cls` e `OpportunityLineTotalsSafe.cls`. Nada neste repositório contém dados reais, clientes ou credenciais.

## Requisitos

- Salesforce CLI (`sf`) atualizado.
- Uma Developer Edition ou um Dev Hub para criar scratch orgs.
- Uma licença Salesforce livre na org: cada teste de persona cria um usuário temporário com o perfil Standard User. Uma scratch org ou Developer Edition nova já atende.
- Opcional, para os portões 1 e 2: Claude Code (o método vale para qualquer agente de código com arquivo de regras e hooks, mas os exemplos usam Claude Code). Para o Portão 2 é preciso `bash` e, de preferência, `jq` (existe fallback com `python3`).

## Instalação

```bash
git clone https://github.com/JeffersonOliveira/apex-agent-gates.git
cd apex-agent-gates

sf org login web -a lab
sf project deploy start -o lab
sf org assign permset --name Lab_Admin_Field_Access -o lab
sf apex run test -o lab --tests CaseNoteSummaryServiceSafe_Test --tests OpportunityLineTotals_Test --result-format human --code-coverage --wait 10
```

O alias `lab` é obrigatório: o `CLAUDE.md` e o hook de deploy esperam esse nome.

O permission set `Lab_Admin_Field_Access` dá ao seu usuário acesso aos dois campos novos. Ele é necessário porque um deploy por source não concede FLS a nenhum perfil e, a partir da API 67.0, o Apex roda SOQL e DML em user mode por padrão. Sem ele, o próprio administrador não consegue criar os dados do laboratório.

O script `scripts/apex/setup-personas.apex` é opcional: cria as personas como usuários reais para testar "Login As". Ele exige 3 licenças Salesforce livres e para sozinho quando a org não tem, para não tomar a licença que os testes usam.

## Mapa: cenário da palestra, arquivo, comando, resultado esperado

| Cenário | Arquivo | Comando | Resultado esperado |
|---|---|---|---|
| T1 vazamento de permissão | `CaseNoteSummaryService.cls` (inseguro), `CaseNoteSummaryServiceSafe.cls` (seguro), `scripts/apex/demo-leak.apex` | `sf apex run -o lab -f scripts/apex/seed-case.apex` e depois `sf apex run -o lab -f scripts/apex/demo-leak.apex` | Como administrador, o serviço inseguro imprime `SECRET`. Para um usuário sem FLS, o seguro lança `QueryException` citando `Internal_Notes__c` (provado no teste). |
| T2 volume e limite | `OpportunityLineTotals.cls`, `OpportunityLineTotalsSafe.cls`, `scripts/apex/demo-limit-error.apex`, `OpportunityLineTotals_Test.cls` | `sf apex run -o lab -f scripts/apex/demo-limit-error.apex` | `System.LimitException: Too many SOQL queries: 101`. O teste do seguro com 200 itens passa com `Limits.getQueries() <= 5`. |
| T3 teste fraco contra teste bom | `CaseNoteSummaryService_WeakTest.cls`, `CaseNoteSummaryServiceSafe_Test.cls`, `TestPersonas.cls` | `scripts/run-persona-tests.sh` | O teste fraco passa e não prova nada. O teste bom falha fechado para a persona restrita, devolve `SECRET` para a persona manager e documenta o vazamento do inseguro. |
| Portão 1: regras | `CLAUDE.md` | Abra o Claude Code na raiz do repositório e peça `tasks/T1.md` | O agente cita as regras (user mode, with sharing, teste com persona) antes de escrever. |
| Portão 2: hooks | `.claude/settings.json`, `.claude/hooks/*.sh` | Peça `tasks/T5.md`; edite uma classe sem `USER_MODE` | Mensagem `BLOCKED by Gate 2` no deploy; devolução `Gate 2 found problems` na edição; linhas em `.claude/logs/tool-calls.jsonl`. |
| Portão 3: pipeline | `.github/workflows/pr-gates.yml` | Abra um pull request (secret `SFDX_AUTH_URL` configurado) ou rode os mesmos comandos localmente | Quatro passos: análise estática, scratch org, deploy de validação, testes com persona. |

`seed-case.apex` só prepara o dado: cria um Case com `Internal_Notes__c = 'SECRET'` para a demonstração do vazamento ter o que mostrar.

Passo a passo detalhado, com o que pode dar errado: [ROTEIRO_CENARIOS.md](ROTEIRO_CENARIOS.md). Tabela para medir as seis tarefas, com e sem portões: [lab/CASOS.md](lab/CASOS.md). Os prompts das tarefas estão em `tasks/T1.md` a `tasks/T6.md`.

## Estrutura

```
CLAUDE.md                 Portão 1
.claude/                  Portão 2 (settings.json e hooks)
.github/workflows/        Portão 3
force-app/main/default/   campos, permission sets e classes
scripts/                  scripts Apex anônimos e execução de testes
tasks/                    as seis tarefas do laboratório
lab/CASOS.md              tabela de medição
```

## Licenças

- Código (classes, scripts, hooks, workflow, metadados): Apache-2.0, ver [LICENSE](LICENSE) e [NOTICE](NOTICE).
- Slides e textos da palestra: CC BY-NC-ND 4.0.

## English summary

1. This is the public lab for the talk "Coding agents in Apex without losing control" (Brazil Dreamin' 2026): a Salesforce DX project using standard Case and Opportunity plus two custom fields.
2. It reproduces three real failure patterns of agent-written Apex: a field-level security leak (system mode), a governor limit failure (SOQL and DML in a loop), and a weak test that only chases coverage.
3. `CaseNoteSummaryService` and `OpportunityLineTotals` are unsafe on purpose and pinned to API 66.0, the last version where Apex defaults to system mode; the `*Safe` classes and the persona tests (`System.runAs`) are the reviewed versions.
4. Three gates contain the agent: project rules (`CLAUDE.md`), hooks (`.claude/`) that block production deploys and review every edited `.cls`, and a pull request pipeline (static analysis, scratch org, validate deploy, persona tests).
5. After deploying, assign the `Lab_Admin_Field_Access` permission set to your user: a source deploy grants no field-level security, and since API 67.0 Apex runs in user mode by default.
6. Code is Apache-2.0 (see NOTICE); slides and texts are CC BY-NC-ND 4.0. No real data or customers are included.
