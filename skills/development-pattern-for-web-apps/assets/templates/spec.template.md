# Spec: <Nome da funcionalidade>

> Modelo de `specs/<nnnn>-<slug>.md`.
> Parte de "Development Pattern for Web Apps": regra R3.
> Uma a três páginas. Se estiver ficando maior, quebre em duas specs.
> Escreva ANTES de qualquer linha de implementação, e **pare para aprovação**.

| | |
| --- | --- |
| **Spec** | `0003-anexos-em-chamados` |
| **Status** | 🟡 aguardando aprovação · 🟢 aprovada · 🔵 implementada · ⚪ descartada |
| **Autor** | <você> · assistida por agente |
| **Data** | 2026-09-05 |
| **Versão alvo** | 1.3.0 |
| **Stack** | Next.js 16 + Tailwind 4 + Supabase (Postgres, Auth, Storage), na Vercel |
| **Nível de segurança** | N1 · **N2** · N3 · N4: ver R7 |

---

## 1. Objetivo

Uma frase: o que o usuário passa a conseguir fazer que hoje não consegue.

> O usuário pode anexar arquivos a um chamado e baixá-los depois, sem precisar
> enviar por e-mail.

## 2. Fora de escopo

O que **não** entra. Existe para impedir o escopo de crescer sozinho durante o build.

- Pré-visualização de imagens dentro da tela do chamado.
- Anexos em comentários (só no chamado).
- Antivírus nos arquivos enviados.

## 3. Requisitos funcionais

Numerados, verificáveis, na voz do usuário. Cada um vira ao menos um caso de teste.

| # | Requisito |
| --- | --- |
| RF-001 | O usuário autenticado pode anexar até 5 arquivos ao seu próprio chamado. |
| RF-002 | Os formatos aceitos são PDF, JPG e PNG, com no máximo 5 MB cada. |
| RF-003 | O usuário vê a lista de anexos com nome original, tamanho e data. |
| RF-004 | O usuário pode baixar um anexo do seu próprio chamado. |
| RF-005 | O usuário pode remover um anexo que ele mesmo enviou, enquanto o chamado estiver aberto. |
| RF-006 | O administrador pode baixar anexos de qualquer chamado. |

## 4. Requisitos não funcionais

- O envio de um arquivo de 5 MB conclui em até 10 s em conexão de 5 Mbps.
- A listagem de anexos não acrescenta consulta por linha (sem N+1).
- Funciona em Chrome, Firefox e Safari, e em telas de 375 px.
- Navegação completa por teclado; rótulos associados a todos os campos.

## 5. Modelo de dados

```sql
CREATE TABLE IF NOT EXISTS public.anexos (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  chamado_id      BIGINT NOT NULL REFERENCES public.chamados (id) ON DELETE CASCADE,
  usuario_id      UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  nome_original   VARCHAR(255) NOT NULL,
  caminho_storage VARCHAR(255) NOT NULL UNIQUE,   -- <usuario_id>/<uuid gerado no servidor>
  mime            VARCHAR(100) NOT NULL,
  tamanho         INTEGER NOT NULL CHECK (tamanho > 0),
  criado_em       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_anexos_chamado ON public.anexos (chamado_id);

-- RLS ligada no mesmo arquivo que cria a tabela (piso P13): sem isso, a API REST
-- do Supabase entrega a tabela a qualquer um com a publishable key.
ALTER TABLE public.anexos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "dono le os proprios anexos" ON public.anexos
  FOR SELECT TO authenticated USING ((select auth.uid()) = usuario_id);
```

- **Migração:** `supabase/migrations/20260905120000_adiciona_anexos.sql` (criada com
  `npx supabase migration new adiciona_anexos`), aditiva, sem perda de dados. A versão
  1.2.1 ignora a tabela nova, então o rollback do código continua seguro (R10). As
  políticas completas (inserir, remover, papel admin lido de `app_metadata`) seguem o
  modelo `politicas-rls.sql.template`.
- **Armazenamento:** Supabase Storage, bucket **privado** `anexos`, com `fileSizeLimit` de
  5 MB e `allowedMimeTypes` PDF, JPG e PNG no próprio bucket, e políticas em
  `storage.objects` por pasta do usuário. O caminho é gerado no servidor
  (`<usuario_id>/<crypto.randomUUID()>`), nunca o nome enviado pelo usuário. Nada vai para
  o disco da função: ele é efêmero.

## 6. Telas e rotas

URLs conforme R15: português, kebab-case, sem extensão, sem estrutura de pastas.

| Rota ou ação | O que faz | Onde |
| --- | --- | --- |
| `/chamados/[id]` | Exibe o chamado e a lista de anexos | `app/chamados/[id]/page.tsx` · `ListaAnexos`, `FormularioAnexo` |
| Server Action `anexarArquivo` | Recebe o upload, valida e grava no Storage | `app/chamados/[id]/acoes.ts` |
| `/anexos/[id]` | Confere o dono e redireciona para uma URL assinada de 60 s | `app/anexos/[id]/route.ts` (Route Handler, `GET`) |
| Server Action `removerAnexo` | Remove o registro e o arquivo no Storage | `app/chamados/[id]/acoes.ts` |

**Rotas renomeadas nesta versão:** nenhuma.
*(Quando houver: `/antiga` → 301 → `/nova`, e a entrada correspondente no CHANGELOG.)*

**Estados de cada tela**: os quatro, sempre:

| Tela | Carregando | Vazio | Erro | Sucesso |
| --- | --- | --- | --- | --- |
| Lista de anexos | esqueleto de 2 linhas | "Nenhum anexo ainda" + botão | mensagem + tentar de novo | a lista |
| Upload | barra de progresso, botão desabilitado | não se aplica | mensagem por arquivo | anexo aparece na lista |

## 7. Regras de negócio

- Máximo de 5 anexos por chamado; o sexto é recusado com mensagem clara.
- Só o autor do chamado e administradores enxergam e baixam os anexos.
- Remover um anexo apaga o registro **e** o arquivo no Storage.
- Fechar o chamado bloqueia novos envios; o download continua permitido.

## 7b. Linguagem (R17)

| | |
| --- | --- |
| **Quem lê** | `<cliente final / colaborador interno / técnico / gestor>` |
| **Domínio** | `<banco / ITSM / saúde / e-commerce / governo / interno>` |
| **Tom** | `<formal / neutro / próximo>` |
| **Vocabulário canônico** | `<os termos do setor que serão usados, e os que não serão>` |
| **Fontes consultadas** | `<3 a 5 produtos reais do domínio, com o que foi observado>` |

Sem travessão em nenhum texto de interface. Corpo de texto justificado com hifenização.

## 8. Segurança

| Item | Decisão |
| --- | --- |
| **Nova superfície de ataque** | Upload de arquivo e download autenticado |
| **Autorização** | Duas camadas: RLS por dono em `anexos` e em `storage.objects`, **e** a conferência do dono no servidor (Server Action e Route Handler) |
| **Validação de tipo** | Assinatura do conteúdo (bytes iniciais) conferida no servidor; o `type` declarado pelo navegador é ignorado |
| **Nome do arquivo** | Chave gerada pelo servidor; o original só é exibido, pelo JSX (escapado) |
| **Local de gravação** | Supabase Storage, bucket privado; nunca o disco da função, nunca bucket público |
| **Entrega** | Sempre pelo Route Handler que confere autorização e gera URL assinada curta (`createSignedUrl(caminho, 60)`); a URL pública do bucket não abre |
| **Limites** | 5 MB por arquivo, conferido na Server Action; `serverActions.bodySizeLimit` em `next.config.ts` ajustado para caber (o padrão é 1 MB, `next@16.4.0`) |
| **Novos segredos** | Nenhum: o Storage usa a URL e as chaves do Supabase que o app já tem. A secret key continua só no servidor |
| **Dado pessoal novo** | O conteúdo dos anexos pode conter: ver a seção 8b |
| **OWASP Top 10 (N2 ou acima)** | `<A01:2025 Broken Access Control: RLS + dono no servidor (CT-SEC-020, CT-SEC-031..033) · A05:2025 Injection: nome do arquivo nunca vira caminho · ... · categoria que não se aplica, com o porquê>` |
| **Revisor humano (N3 ou acima)** | `<NOME-DO-REVISOR>`, `<DATA>`: leu todo o código de autenticação, pagamento, webhook e dado sensível desta spec. Sem nome, o ⛔ da Fase 6 não abre |

## 8b. Dados pessoais

Cada campo pessoal que a funcionalidade coleta ou guarda, com finalidade e prazo. Campo
sem finalidade escrita aqui **não entra** no formulário (CT-LGPD-004). A política de
privacidade (`/politica-de-privacidade`) cita estes campos no mesmo commit.

| Campo | Finalidade | Retenção |
| --- | --- | --- |
| Conteúdo dos anexos (pode conter dado pessoal de terceiros) | Atender o chamado | `<2 anos após o fechamento do chamado; apagado junto com a conta>` |
| `nome_original` do arquivo | Exibir ao dono e ao atendente | Igual ao anexo |
| `<campo>` | `<para que serve, em uma frase>` | `<prazo, e o que acontece depois: apagado, anonimizado>` |

Exclusão de conta alcança: a linha em `anexos`, os arquivos no bucket e o usuário no Auth.
O que permanece em backup, e por quanto tempo: `<ex.: até 7 dias, o ciclo do backup diário do plano Pro>`.

## 9. Critérios de aceite

Um por requisito, em formato observável.

```
RF-001
  DADO um chamado aberto do próprio usuário, sem anexos
  QUANDO ele seleciona um PDF de 2 MB e envia
  ENTÃO o anexo aparece na lista com nome original, "2,0 MB" e a data de hoje,
    e a contagem passa a exibir "1 de 5"

RF-004 (negativo)
  DADO o usuário A autenticado
  QUANDO ele acessa /anexos/{id de um anexo do usuário B}
  ENTÃO a resposta é 404 e nenhum byte do arquivo é entregue
```

## 10. Casos de teste

Alimentam `qa/roteiro-de-testes.md` (R11).

| Caso | Cobre | Tipo |
| --- | --- | --- |
| CT-030 | RF-001 caminho feliz | Funcional |
| CT-031 | RF-002 arquivo de 6 MB recusado | Funcional |
| CT-032 | RF-002 arquivo .exe recusado | Funcional |
| CT-033 | RF-001 sexto anexo recusado | Fronteira |
| CT-034 | RF-003 estado vazio | Interface |
| CT-035 | RF-005 remoção apaga registro e arquivo | Integração |
| CT-SEC-020 | RF-004 anexo de outro usuário → 404 | Segurança (IDOR) |
| CT-SEC-021 | `teste.html` renomeado para `.jpg` é recusado | Segurança |
| CT-SEC-022 | A URL assinada expira em 60 s; depois disso, recusada | Segurança |
| CT-SEC-023 | Nome com `<script>` é exibido escapado | Segurança (XSS) |
| CT-SEC-024 | `/anexos/..%2F..%2F.env.local` → 404 | Segurança (traversal) |
| CT-UI-020 | `/chamados/8/` e `/Chamados/8` → 308 para a forma canônica | Rotas |
| CT-UI-021 | `/anexos/abc` (id não numérico) → 404, sem erro 500 | Rotas |
| CT-SEC-033 | URL pública de arquivo do bucket privado não abre; URL assinada expirada é recusada | Segurança (Storage) |
| CT-SEC-031 | `anexos` pela API REST, com a publishable key e sem login: nenhuma linha | Segurança (RLS) |
| CT-MIG-010 | Com a migração `20260905120000` aplicada, o deploy da 1.2.1 passa na fumaça | Migração (R10) |

## 11. Impacto na documentação e no release

- [ ] Versão: **1.3.0** (MINOR: funcionalidade nova, compatível)
- [ ] CHANGELOG: entrada em "Adicionado" + a migração
- [ ] README: bucket `anexos` (privado) e seus limites na seção de armazenamento
- [ ] Roteiro de QA: 16 casos novos, 7 deles de segurança
- [ ] Política de privacidade: cita os anexos (seção 8b)
- [ ] Migração `20260905120000` aplicada com `supabase db push` antes da promoção, com o
      backup do dia conferido (R10)

## 12. Evidências

| Afirmação | Fonte | Verificado |
| --- | --- | --- |
| `createSignedUrl(path, expiresIn)` existe | `@supabase/storage-js` 2.117.3, `dist/index.d.cts` l.1348 | ✅ 2026-10-10 |
| `createBucket` aceita `fileSizeLimit` e `allowedMimeTypes` | `@supabase/storage-js` 2.117.3, `dist/index.d.cts` l.1986-1989 | ✅ 2026-10-10 |
| Tabela no schema exposto sem RLS é legível e gravável por qualquer papel com grant | supabase.com/docs/guides/database/postgres/row-level-security | ✅ 2026-10-10 |
| Corpo de Server Action tem limite padrão de 1 MB | `next@16.4.0`, `dist/server/app-render/action-handler.js` | ✅ 2026-10-10 |
| `serverActions.bodySizeLimit` existe em `NextConfig` | `next@16.4.0`, `dist/server/config-shared.d.ts` | ✅ 2026-10-10 |
| SVG é vetor de XSS | OWASP File Upload Cheat Sheet | ✅ 2026-09-05 |

## 13. Questões em aberto

1. Anexos devem ser mantidos quando o chamado é excluído, ou apagados junto?
   *(proposta: apagados, `ON DELETE CASCADE` + remoção do arquivo no Storage)*
2. O administrador pode remover anexo de outro usuário?
   *(proposta: sim, com registro em auditoria)*

---

## Aprovação

| | |
| --- | --- |
| **Aprovada em** | <data> |
| **Por** | <usuário> |
| **Forma** | revisada item a item · aprovada sem revisão ("pode fazer") |
| **Alterações pedidas** | <nenhuma / lista> |
