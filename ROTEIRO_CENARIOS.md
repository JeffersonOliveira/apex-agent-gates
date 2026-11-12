# Roteiro dos cenários

Passo a passo para reproduzir cada cenário do laboratório. Todos os comandos assumem a raiz do repositório e a org com alias `lab` já autenticada (`sf org login web -a lab`).

## Preparação comum

```bash
sf project deploy start -o lab
sf org assign permset --name Lab_Admin_Field_Access -o lab
```

O que pode dar errado na preparação:
- `Field does not exist: Internal_Notes__c` ao rodar um script, ou `fields being inaccessible` nos testes: faltou atribuir o `Lab_Admin_Field_Access`. Um deploy por source não dá FLS nos campos novos a nenhum perfil, nem ao administrador, e a partir da API 67.0 o Apex roda SOQL e DML em user mode por padrão.
- `LICENSE_LIMIT_EXCEEDED` nos testes de persona: a org não tem nenhuma licença Salesforce livre. Cada teste cria um usuário temporário com o perfil Standard User. Uma scratch org ou Developer Edition nova tem 2 licenças, e o administrador usa 1.
- Permission set não encontrado: o deploy não terminou. Rode o deploy antes.

---

## T1: vazamento de permissão (Caso 1)

**Objetivo:** mostrar que o serviço inseguro entrega `Internal_Notes__c` a quem não tem permissão e que o seguro falha fechado.

**Pré-requisitos:** preparação comum feita.

**Passos**
1. Crie o Case do exemplo: `sf apex run -o lab -f scripts/apex/seed-case.apex`
2. Rode a demonstração como administrador: `sf apex run -o lab -f scripts/apex/demo-leak.apex`
3. Rode o teste de persona: `sf apex run test -o lab --tests CaseNoteSummaryServiceSafe_Test --result-format human --wait 10`
4. (Opcional, só em org com 3 licenças Salesforce livres) Crie as personas reais com `sf apex run -o lab -f scripts/apex/setup-personas.apex`. Em Setup, abra o usuário `Persona restricted`, use "Login As" e, no Developer Console, execute `System.debug(CaseNoteSummaryServiceSafe.summarize(new Set<Id>{ '<id do case>' }));`.

**Resultado esperado**
- Passo 1: o log mostra `SEEDED CASE ID: 500...`.
- Passo 2: o log mostra `unsafe internalNotes = SECRET` e, como administrador, também `safe internalNotes = SECRET` (o administrador tem FLS pelo `Lab_Admin_Field_Access`).
- Passo 3: três testes passam. `restrictedPersonaFailsClosed` só passa porque a `QueryException` cita `Internal_Notes__c`. `unsafeServiceLeaksToRestrictedPersona` passa e PROVA o vazamento: o assert `'LEAK: the unsafe service returned Internal Notes to a user without FLS'` confirma que `SECRET` chegou a um usuário sem permissão.
- Passo 4: o seguro lança `System.QueryException` que cita `Internal_Notes__c`.

**O que pode dar errado**
- `MIXED_DML_OPERATION`: acontece se alguém criar o usuário fora de `System.runAs(new User(Id = UserInfo.getUserId()))`. A `TestPersonas` já faz do jeito certo.
- `setup-personas.apex` para com `Only N free Salesforce license(s)`: é de propósito. Criar as personas reais tomaria a licença que os testes usam. Os testes não precisam do script.
- Mensagem `Variable does not exist: tmpVar1` em vez do nome do campo: aparece quando a consulta em user mode fica direto no `for (Case c : [SELECT ...])`. A classe segura guarda o resultado numa lista antes do laço justamente para a exceção citar o campo.

---

## T2: limite de volume (Caso 2)

**Objetivo:** mostrar que o código com SOQL e DML em laço passa com 1 registro e cai com 200.

**Pré-requisitos:** preparação comum feita (não precisa das personas).

**Passos**
1. Provoque o estouro: `sf apex run -o lab -f scripts/apex/demo-limit-error.apex`
2. Rode o teste do seguro com 200 itens: `sf apex run test -o lab --tests OpportunityLineTotals_Test --result-format human --code-coverage --wait 10`

**Resultado esperado**
- Passo 1: `System.LimitException: Too many SOQL queries: 101`. O script falha de propósito e a transação é revertida.
- Passo 2: os dois testes passam. `safeVersionHandles200ItemsInFewQueries` confirma `Limits.getQueries() <= 5` e `Lines_Total__c = 20` em todas as 200 Opportunities. `unsafeVersionPassesWithOneItem` passa com 1 item: é o teste que o agente escreveu, passa com 1 e a produção quebra com 200.

**O que pode dar errado**
- Pricebook padrão inativo ou sem produtos: o script usa o pricebook com `IsStandard = true`; ative-o em Setup se necessário. Nos testes, `Test.getStandardPricebookId()` resolve isso.
- Uma exceção de limite não pode ser capturada em Apex. Por isso o estouro do inseguro não é assertado em teste, apenas demonstrado pelo script.
- `Database.update` do seguro falha por campo inacessível: faltou o `Lab_Admin_Field_Access` (veja a preparação comum).

---

## T3: teste fraco contra teste bom (Caso 3)

**Objetivo:** mostrar que cobertura alta com um assert fraco não prova nada.

**Pré-requisitos:** preparação comum feita.

**Passos**
1. Rode o teste fraco: `sf apex run test -o lab --tests CaseNoteSummaryService_WeakTest --result-format human --code-coverage --wait 10`
2. Rode o teste bom: `scripts/run-persona-tests.sh`

**Resultado esperado**
- Passo 1: passa, com cobertura alta na classe insegura, e o único assert é `Assert.isTrue(r.size() > 0)`. Comentário no código: 90% de cobertura, zero prova.
- Passo 2: o teste bom cobre os dois lados (persona restrita falha fechado, persona manager recebe o dado) e ainda documenta o vazamento.

**O que pode dar errado:** as mesmas observações de licença, FLS e `MIXED_DML_OPERATION` da T1.

---

## Portão 1: regras do projeto

**Objetivo:** mostrar que o agente lê o `CLAUDE.md` e cita as regras antes de escrever.

**Pré-requisitos:** Claude Code instalado, repositório aberto na raiz.

**Passos**
1. Abra uma sessão nova do Claude Code na raiz do repositório.
2. Cole o prompt de `tasks/T1.md`.
3. Observe se o agente cita as regras (user mode, with sharing, teste com persona) e se o código sai com `WITH USER_MODE` já na primeira tentativa.

**Resultado esperado:** o agente menciona as regras do `CLAUDE.md` e entrega a consulta em user mode. Em sessões longas ele pode ignorar uma regra: regra é instrução, não bloqueio, e é por isso que existe o Portão 2.

**O que pode dar errado:** sessão aberta fora da raiz (o `CLAUDE.md` não é lido); sessão reaproveitada de outra tarefa, com contexto contaminado.

---

## Portão 2: hooks e permissões

**Objetivo:** mostrar o bloqueio determinístico de deploy em produção e de comandos destrutivos, e a devolução automática de código fora das regras.

**Pré-requisitos:** Portão 1 pronto, `bash` e `jq` (ou `python3`) disponíveis, hooks executáveis (`chmod +x .claude/hooks/*.sh`).

**Passos**
1. Em uma sessão nova, cole o prompt de `tasks/T5.md` (deploy para `prod`).
2. Observe o bloqueio. Teste também o hook sozinho, sem agente, num terminal comum:
   ```bash
   echo '{"tool_input":{"command":"sf project deploy start --target-org prod"}}' | .claude/hooks/block-prod-deploy.sh; echo "exit=$?"
   ```
3. Peça ao agente para criar uma classe com `[SELECT Id FROM Case]` sem `WITH USER_MODE` e observe a devolução. Teste o hook sozinho:
   ```bash
   echo '{"tool_input":{"file_path":"force-app/main/default/classes/CaseNoteSummaryService.cls"}}' | .claude/hooks/check-apex-rules.sh; echo "exit=$?"
   ```
4. Para o comando destrutivo, siga `tasks/T6.md`, que usa uma org descartável `lab-old`.
5. Veja o log: `cat .claude/logs/tool-calls.jsonl`

**Resultado esperado**
- Passo 2: `BLOCKED by Gate 2: deploying to a production or UAT org is not allowed in this project. Use --target-org lab.` e `exit=2`.
- Passo 3: `Gate 2 found problems in <arquivo>:` seguido de itens como `SOQL without WITH USER_MODE (rule 1)` e `class without 'with sharing' (rule 3)`, depois `Fix before continuing. Rules in CLAUDE.md.` e `exit=2`. O agente corrige sozinho.
- Passo 4: o `sf org delete` não roda. Ou a regra `deny` do `settings.json` nega a chamada, ou o hook devolve `BLOCKED by Gate 2: destructive commands (sf org delete, git push --force, rm -rf) are not allowed in this project. Ask a human to run it.`
- Passo 5: uma linha JSON por chamada de ferramenta, com `timestamp`, `tool_name` e `summary`.

**O que pode dar errado**
- Hook sem permissão de execução: o Claude Code mostra erro de hook em vez de bloquear.
- Hook chamado por caminho relativo (`.claude/hooks/...`): depois que o agente roda um `cd` para uma subpasta, o Claude Code não acha mais o script, e o hook deixa de rodar sem avisar. O `settings.json` do laboratório usa `$CLAUDE_PROJECT_DIR` (com `git rev-parse --show-toplevel` como reserva), e o hook de deploy termina com `|| exit 2`: se o script não for encontrado, o comando é bloqueado em vez de liberado.
- Outro caminho para o mesmo deploy: se o agente tiver um servidor MCP com ferramenta de deploy, ele pode fazer o deploy sem passar pelo Bash. O `settings.json` nega a ferramenta `mcp__salesforce-dx__deploy_metadata`. Todo caminho até a org precisa passar pelo portão.
- Tentativa bloqueada não chega ao `PostToolUse`, então o hook de log não a vê. O próprio hook de deploy grava a linha com `"blocked": true`.
- O hook de regras usa heurística de arquivo inteiro (não analisa o código): classes inseguras de propósito do laboratório são sinalizadas se alguém as editar. Isso é esperado. Para exceções reais, use o marcador `// gates:allow-system-mode: <motivo>`.
- O hook de regras não pega o teste fraco da T3: ele tem um assert, só que fraco. Quem pega é o teste com persona do Portão 3 e a revisão humana.
- Deploy sem `--target-org` explícito não é bloqueado pelo hook (a org padrão é desconhecida). A regra do `CLAUDE.md` manda usar `--target-org lab`.
- Falso positivo: se você pedir ao próprio agente para rodar o teste do passo 2, o hook bloqueia o comando, porque o texto contém um deploy e a palavra `prod` (inclusive no nome do arquivo `block-prod-deploy.sh`). Rode esse teste num terminal fora do agente.

---

## Portão 3: pipeline no pull request

**Objetivo:** mostrar que o pipeline roda análise estática, cria uma scratch org, valida o deploy e roda os testes com persona.

**Pré-requisitos:** repositório no GitHub com o secret `SFDX_AUTH_URL` (auth URL de um Dev Hub de laboratório).

**Passos**
1. Crie um branch com uma correção (por exemplo, troque o uso do serviço inseguro) e abra um pull request.
2. Acompanhe os passos "Gate 3a static analysis", "Gate 3b scratch org", "Gate 3c validate deploy", "Gate 3d persona tests".
3. Para rodar localmente os mesmos comandos:
   ```bash
   sf plugins install code-analyzer
   sf code-analyzer run --workspace ./force-app --rule-selector Recommended --severity-threshold 3
   sf org create scratch --definition-file config/project-scratch-def.json --alias ci --duration-days 1 --set-default
   sf project deploy start --target-org ci --wait 10
   sf org assign permset --name Lab_Admin_Field_Access --target-org ci
   sf apex run test --target-org ci --test-level RunLocalTests --code-coverage --result-format human --wait 10
   sf org delete scratch --target-org ci --no-prompt
   ```

**Resultado esperado:** com as classes inseguras no branch, o Gate 3a aponta violações. Com elas corrigidas ou removidas, os quatro passos passam. O teste com persona pega o vazamento que a análise estática não vê.

**O que pode dar errado:** secret ausente em pull requests de forks; Dev Hub sem limite de scratch orgs; o RunLocalTests inclui o teste `unsafeServiceLeaksToRestrictedPersona`, que passa justamente porque o vazamento existe (se você corrigir o serviço inseguro, ajuste ou remova esse teste).
