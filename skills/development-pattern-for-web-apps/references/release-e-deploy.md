# Release e deploy: versão, documentação e caminho de volta

> Regra **R13**: versão, documentação e schema andam juntos, no mesmo commit.
> Regra **R14**: nenhum deploy sem alvo nomeado, sem backup e sem caminho de volta. Na
> Vercel: preview → ⛔ → produção, com a migração aplicada antes da promoção e o
> `vercel rollback` como caminho de volta.

---

## 1. Versionamento semântico, em termos de app

`MAJOR.MINOR.PATCH`, e o significado é **para quem usa o app**, não para quem o escreve.

| Nível | Quando | Exemplos |
| --- | --- | --- |
| **MAJOR** | Quebra algo para quem já usa | Migração que apaga coluna; mudança de URL de rota existente; requisito novo de ambiente (Node 22 → 24, variável obrigatória nova); mudança que exige reconfiguração manual |
| **MINOR** | Funcionalidade nova, compatível | Módulo novo; campo novo opcional; painel novo; migração aditiva |
| **PATCH** | Correção sem mudança de comportamento esperado | Bug, ajuste de texto, correção de segurança sem quebra, melhoria de desempenho |

Duas decisões que quase todo mundo erra:

- **Correção de segurança que muda comportamento é MAJOR ou MINOR, não PATCH.** Se o
  usuário precisa refazer a senha ou reconectar, não é patch.
- **Migração que remove ou renomeia coluna é MAJOR**, mesmo que o diff tenha três linhas:
  ela quebra o código da versão anterior, e é justamente para essa versão que o rollback
  volta (R10).

### Onde a versão vive

| O quê | Fonte da verdade |
| --- | --- |
| App | `package.json` → `version` |
| Banco | tabela `supabase_migrations.schema_migrations`, mantida pelo Supabase CLI: a última migração registrada diz até onde o schema está |

O `package.json` é a fonte da verdade, não uma tag do Git. A tag é opcional; a versão
exibida no rodapé e no painel administrativo sai do arquivo:

```ts
// lib/versao.ts: a versão não é segredo, pode aparecer no rodapé
import pacote from '../package.json';
export const VERSAO_DO_APP = pacote.version;
```

Importar JSON assim exige `"resolveJsonModule": true` no `tsconfig.json`. O próprio
`next build` grava esse valor quando o `tsconfig.json` não o tem (`next@16.4.0`,
`dist/lib/typescript/writeConfigurationDefaults.js`); confira no seu.

**Exiba a versão na aplicação**: rodapé, ou tela "Sobre" do painel. Sem isso, ninguém sabe
qual deploy está em produção depois de um rollback.

---

## 2. O que muda junto com a versão

> A matriz completa de mudança → documento está em
> [documentacao-do-projeto.md](documentacao-do-projeto.md). A tabela abaixo é o recorte
> que interessa no momento do release.

| A mudança… | Exige atualizar |
| --- | --- |
| Comportamento visível ao usuário | CHANGELOG, README (seção de uso), roteiro de QA |
| Requisito de ambiente (versão do Node, serviço do Marketplace) | README (pré-requisitos), `engines` no `package.json` |
| Passo de instalação ou configuração | README (instalação), `.env.example`, `scripts/seed.ts` (R9) |
| Schema do banco | Migração em `supabase/migrations/<timestamp>_<nome>.sql` (criada com `supabase migration new`), registrada em `supabase_migrations.schema_migrations`, CHANGELOG dizendo se é aditiva (R10) |
| Variável de ambiente nova | `lib/env.ts`, `.env.example`, README, painel da Vercel **nos três ambientes** (R9) |
| Nova superfície de ataque | Spec (seção de segurança), roteiro de QA (casos `CT-SEC`) |
| Correção de defeito | CHANGELOG, caso `CT-REG-nnn` no roteiro |

Um commit que muda comportamento sem subir a versão e sem atualizar a documentação é, sob
este padrão, um **commit incompleto**.

---

## 3. CHANGELOG

Formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/), escrito para quem usa
o app, não para quem leu o diff.

```markdown
## [1.3.0] - 2026-09-05

### Adicionado
- Anexos em chamados: até 5 arquivos de 5 MB por chamado (PDF, JPG, PNG), guardados no
  Supabase Storage em bucket privado.

### Corrigido
- Busca com apóstrofo (`O'Brien`) deixava a listagem em branco.
- Download de anexo não verificava o dono do chamado: qualquer usuário autenticado
  conseguia baixar anexos de outros. **Atualize assim que possível.**

### Migrações
- `20260905120000_adiciona_anexos.sql`, cria a tabela `anexos` com RLS ligada e o
  bucket privado `anexos`. Aditiva, sem perda de dados.
- `20260905120100_indice_status_data.sql`, índice composto em `chamados`. Pode levar
  alguns segundos em bases grandes.

### Requisitos
- Nenhuma variável nova: o Storage usa a URL e as chaves do Supabase que o app já tem.
```

Falha de segurança corrigida é **nomeada**, com a urgência de atualizar. Esconder isso do
CHANGELOG deixa quem usa a versão antiga sem saber que precisa subir.

---

## 4. A sequência de release

```bash
# 1. Validação completa (Fase 4)
npx tsc --noEmit && npm run lint && npm test && npm run build

# 2. Varreduras
bash skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh
bash skills/development-pattern-for-web-apps/assets/scripts/scan-sql-injection.sh
npm audit --omit=dev
# alertas do Dependabot do repositório lidos: nenhum crítico ou alto aberto sem decisão
gh api repos/{owner}/{repo}/dependabot/alerts --jq '.[] | select(.state=="open") | [.security_advisory.severity, .dependency.package.name] | @tsv'

# 3. QA (Fase 5): roteiro executado; nenhum defeito 🔴 em aberto

# 4. Versão + documentação, no MESMO commit
#    - version no package.json
#    - CHANGELOG com entrada datada
#    - README, se instalação/configuração/uso mudaram
#    - qa/roteiro-de-testes.md atualizado
#    - spec atualizada, se o comportamento mudou

# 5. Revisão (R12) contra o diff real
git diff --cached

# 6. ⛔ APROVAÇÃO: nomeando a versão e o que muda

git commit -m "feat(anexos): permitir anexar arquivos ao chamado

Fecha RF-012. Migração 0007 aditiva. Corrige também a verificação de dono
no download de anexos (CT-SEC-009 / DEF-014).

Versão 1.3.0."

git push -u origin feat/anexos-em-chamados
```

---

## 5. Deploy na Vercel: preview → ⛔ → produção

⛔ **Portão.** "É só um push" ainda é uma publicação. Nomeie o alvo e espere o sim:

> Pronto para publicar **Controle de Chamados v1.3.0** em **`https://seu-dominio.com.br`**
> (projeto Vercel `controle-de-chamados`, ambiente Production). Uma migração pendente:
> `20260905120000_adiciona_anexos.sql`, aditiva e compatível com a v1.2.0. Confiro o
> backup do dia do Supabase (ou gero um `supabase db dump`) antes de aplicá-la. Confirma?

| Ambiente | Origem | Banco | Uso |
| --- | --- | --- | --- |
| Development | sua máquina (`vercel env pull .env.local`) | Supabase local (`npx supabase start`) ou projeto de desenvolvimento separado | Escrever e testar |
| Preview | cada push num ramo / PR | **branch de preview do Supabase** (Branching), ou projeto separado; nunca o de produção | **Onde o roteiro de QA (R11) é executado** |
| Production | merge em `main`, ou `vercel promote` | produção | Só depois do QA verde no preview e da aprovação |

Sequência:

1. **Push no ramo de trabalho** → deploy de preview com URL própria.
2. **Migração no branch de preview do Supabase**: com o Branching ligado, o branch do PR
   aplica as migrações novas e o seed sozinho; com projeto separado,
   `npx supabase db push` contra ele. Depois, o roteiro de QA contra a URL de preview.
3. Nenhum defeito 🔴 aberto → ⛔ **aprovação**, com versão e alvo nomeados.
4. **Ponto de restauração do banco de produção**: o backup diário do dia existe no painel do
   Supabase (Database > Backups, planos pagos), ou um dump feito agora, com o nome da
   versão, guardado fora do repositório:

   ```bash
   npx supabase link --project-ref SEU-PROJECT-REF-DE-PRODUCAO
   npx supabase db dump --linked -f ../backups/v1.3.0-roles.sql --role-only
   npx supabase db dump --linked -f ../backups/v1.3.0-schema.sql
   npx supabase db dump --linked -f ../backups/v1.3.0-dados.sql --data-only --use-copy
   ```

   Sem flag, o `db dump` grava só o schema (`--schema-only` no `pg_dump`, conferido com
   `supabase db dump --dry-run`, CLI 2.120.0): os dados exigem `--data-only`.
5. **Migração em produção, antes da promoção.** Com o projeto de produção linkado:
   `npx supabase db push --dry-run` (lista o que será aplicado), depois
   `npx supabase db push`. Ela é compatível com o código que está no ar (R10), então o app
   atual continua funcionando enquanto o novo não sobe.
6. **Promoção:** merge em `main` (o deploy de produção acontece sozinho) ou, para promover
   exatamente o deploy de preview que passou no QA, `vercel promote <url-do-preview>`.
7. **Conferir** no painel, ou com `vercel inspect <url>`, que o deploy de produção terminou.
8. **Fumaça em produção:** a home carrega; o login entra; a tela do módulo alterado
   funciona; a versão exibida no rodapé é a nova; `curl -I https://seu-dominio.com.br`
   mostra os cabeçalhos de segurança.

Cuidados específicos:

- **A Vercel não roda a sua migração.** O deploy sobe o código; o schema só muda quando
  alguém roda `supabase db push`. Por isso o passo 5 vem **antes** do 6, e por isso a migração
  precisa aceitar o código antigo e o novo ao mesmo tempo.
  → [migracoes-e-rollback.md](migracoes-e-rollback.md)
- **Variável de ambiente nova precisa existir no painel antes do deploy** que a usa,
  incluindo o ambiente de Preview. Se faltar, `lib/env.ts` derruba o build com o nome dela
  (R9), em vez de o app quebrar em produção.
- **Build falhou?** Não empurre outra tentativa às cegas: o ciclo é log → reprodução com
  `vercel build` → correção da causa raiz → prova local → um push, com teto de três voltas.
  → [vercel-build-e-correcao.md](vercel-build-e-correcao.md)

### Caminho de volta

Escreva isso **antes** de precisar dele, no README:

```
1. Código: vercel rollback <url-do-deploy-anterior>
   (ou o Instant Rollback, pelo painel da Vercel).
2. Fumaça: a versão no rodapé voltou à anterior? O fluxo que quebrou voltou a funcionar?
3. Banco: NÃO volta junto. Como a migração era compatível com a versão anterior (R10),
   nada a fazer. Se não era, restaurar o backup do passo 4 (painel do Supabase, Database >
   Backups; o projeto fica indisponível durante a restauração).
4. Conferir supabase_migrations.schema_migrations: a última linha é a que a versão
   restaurada espera?
5. Registrar o incidente no CHANGELOG e abrir CT-REG para o defeito.
```

`vercel rollback` e `vercel promote` recebem a URL ou o id do deploy (*verificado em vercel
63.1.2, 2026-10-10*: "Quickly revert back to a previous deployment" e "Promote an existing
Deployment to current"). Confira com `vercel rollback --help` na sua versão.

---

## 6. Migrações: expand → migrate → contract

Remover uma coluna sem derrubar o app leva **três releases**, não uma. É o que mantém o
Instant Rollback seguro em todo momento:

```
v1.4.0  expand    Adiciona a coluna nova. O código escreve nas duas, lê da antiga.
v1.5.0  migrate   Copia os dados. O código lê da nova. A antiga continua existindo, sem uso.
v1.6.0  contract  Remove a coluna antiga.   ← só aqui, com ponto de restauração
```

Em qualquer um desses releases, voltar o código uma versão funciona, porque o schema ainda
tem o que a versão anterior lê. É mais lento e é a diferença entre um rollback entediante e
uma noite perdida restaurando dump.

Detalhe completo, formato dos arquivos e o registro em `supabase_migrations.schema_migrations`:
→ [migracoes-e-rollback.md](migracoes-e-rollback.md)

---

## 7. A versão do schema

`supabase_migrations.schema_migrations` é o registro da versão do banco: uma linha por
migração aplicada, na ordem. Ela responde à pergunta que o rollback faz: "este banco está
onde o código espera?"

```bash
npx supabase migration list          # local x remoto, lado a lado, no projeto linkado
psql "$POSTGRES_URL" -c "SELECT version, name FROM supabase_migrations.schema_migrations ORDER BY version DESC LIMIT 3;"
```

---

## 8. Backup: existe antes de precisar, e a restauração já foi ensaiada

O backup de antes da migração (§5, passo 4) cobre o release. O dia a dia precisa de outro,
independente de migração, porque o dado também se perde por erro de operação, bug ou conta
comprometida. O que o Supabase oferece por plano (supabase.com/docs/guides/platform/backups,
conferido em 2026-10-10):

| Plano | Backup automático | O que fazer |
| --- | --- | --- |
| Free | Nenhum descrito na documentação, que recomenda exportar regularmente com `supabase db dump` | Dump agendado (os três comandos do §5, passo 4), guardado **fora** do Supabase e fora do repositório |
| Pro | Diário, últimos 7 dias | Conferir que existe; restauração pelo painel em Database > Backups |
| Team | Diário, últimos 14 dias | Idem |
| PITR | Add-on pago (Pro ou acima), exige compute Small ou maior | Só se o nível do app pedir (N3/N4) |

Backup que nunca foi restaurado é hipótese. **Ensaie** a restauração num projeto
descartável, antes do primeiro lançamento e a cada trimestre, e rode a fumaça contra ele:
é o caso CT-MIG-011 do roteiro de testes. Anote quanto tempo levou: durante uma restauração
real o projeto fica indisponível, e esse número é o tempo que o app fica fora do ar.
Detalhes: [migracoes-e-rollback.md](migracoes-e-rollback.md).

A versão do app (`package.json`) e a última migração registrada aparecem juntas no
CHANGELOG de cada release, para que qualquer pessoa saiba qual par está em produção.

---

## 9. Checklist de release

- [ ] Fase 4 (validação) completa, resultados reportados como são
- [ ] Fase 5 (QA) executada; nenhum defeito 🔴 em aberto
- [ ] `version` subida no `package.json`, nível SemVer justificado
- [ ] CHANGELOG com entrada datada, escrita para o usuário
- [ ] README atualizado se instalação, configuração ou uso mudaram
- [ ] Roteiro de QA e spec atualizados no mesmo commit
- [ ] Migrações em `supabase/migrations/`, registradas em `supabase_migrations.schema_migrations`, testadas em base limpa **e** em base com dados
- [ ] Toda migração compatível com o código da versão anterior; destrutiva só no contract (R10)
- [ ] Migração aplicada em produção **antes** da promoção
- [ ] Ponto de restauração (backup diário do Supabase conferido, ou `supabase db dump`) criado antes de migrar produção
- [ ] Restauração ensaiada nos últimos três meses (CT-MIG-011), com o tempo anotado
- [ ] Variáveis novas existem no painel em Production **e** Preview
- [ ] Caminho de volta (`vercel rollback`) documentado no README
- [ ] Varreduras limpas; `npm audit --omit=dev` sem crítico
- [ ] Alertas do Dependabot lidos: nenhum crítico ou alto aberto sem decisão registrada;
      `.github/dependabot.yml` presente (template `dependabot.yml.template`)
- [ ] ⛔ Aprovação para o push, com a versão nomeada
- [ ] ⛔ Aprovação para a promoção a produção, com a versão e o alvo nomeados
- [ ] Fumaça em produção depois de publicar, e o resultado relatado
